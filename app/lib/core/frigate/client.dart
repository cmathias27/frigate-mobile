import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'capabilities.dart';
import 'certificate_guard.dart';
import 'ptz.dart';
import 'recordings.dart';
import 'reviews.dart';
import 'server_config.dart';

/// Thrown when authentication with Frigate fails.
class FrigateAuthException implements Exception {
  final String message;
  final int statusCode;

  const FrigateAuthException(this.message, {this.statusCode = 401});

  @override
  String toString() => 'FrigateAuthException($statusCode): $message';
}

/// Thrown when network or connection fails.
class FrigateNetworkException implements Exception {
  final String message;
  final Object? cause;

  const FrigateNetworkException(this.message, [this.cause]);

  @override
  String toString() =>
      'FrigateNetworkException: $message${cause != null ? " ($cause)" : ""}';
}

/// The address used could not be reached at all (no route, timeout,
/// refused certificate): the other address of the server may work.
class FrigateUnreachableException extends FrigateNetworkException {
  const FrigateUnreachableException(super.message, [super.cause]);
}

/// The local address presented a self-signed certificate the user has not
/// confirmed yet, or one that changed since (decision 0004, point 4).
class FrigateCertificateException extends FrigateUnreachableException {
  /// SHA-256 fingerprint of the certificate presented.
  final String fingerprint;

  /// Whether another certificate was confirmed before.
  final bool changed;

  const FrigateCertificateException(
    this.fingerprint, {
    required this.changed,
    Object? cause,
  }) : super('Server certificate to confirm.', cause);
}

abstract final class AddressDefaults {
  /// Time given to the local address before the remote one is used.
  static const probe = Duration(seconds: 3);
}

/// HTTP client for interacting with a Frigate NVR server on port 8971
/// (decision 0004).
///
/// Port 5000 is intentionally unsupported to enforce authenticated access.
class FrigateClient {
  final ServerConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final CertificateGuard _certificates;

  String? _token;
  String _cookieName = defaultCookieName;
  String _activeBaseUrl;

  FrigateClient({
    required ServerConfig config,
    String? token,
    http.Client? client,
    String? activeBaseUrl,
  }) : this._(config, token, client, activeBaseUrl, CertificateGuard(config));

  FrigateClient._(
    this.config,
    this._token,
    http.Client? client,
    String? activeBaseUrl,
    this._certificates,
  ) : _client = client ?? _createDefaultClient(_certificates),
      _ownsClient = client == null,
      _activeBaseUrl = activeBaseUrl ?? config.localUrl;

  /// Certificates refused on the local address (tests simulate one).
  @visibleForTesting
  CertificateGuard get certificates => _certificates;

  /// Called when requests move to the other address of the server.
  void Function(String url)? onAddressChanged;

  String get activeBaseUrl => _activeBaseUrl;

  /// Whether requests go to the remote address.
  bool get usingRemote =>
      config.remoteUrl != null && _activeBaseUrl == config.remoteUrl;

  /// The address other than [url], when the server has two.
  String? _alternate(String url) {
    final remote = config.remoteUrl;
    if (remote == null || remote.isEmpty || remote == config.localUrl) {
      return null;
    }
    return url == remote ? config.localUrl : remote;
  }

  void _use(String url) {
    if (_activeBaseUrl == url) return;
    _activeBaseUrl = url;
    onAddressChanged?.call(url);
  }

  /// Picks the local address when it answers within
  /// [AddressDefaults.probe], the remote one otherwise. Any HTTP answer
  /// counts: only reaching the server matters here, so the probe carries no
  /// session (on another network, the local address may be someone else).
  Future<String> resolveAddress({
    Duration probe = AddressDefaults.probe,
  }) async {
    final remote = _alternate(config.localUrl);
    if (remote == null) {
      _use(config.localUrl);
      return _activeBaseUrl;
    }
    try {
      await _client
          .get(
            Uri.parse('${config.localUrl}/api/version'),
            headers: const {'Accept': 'text/plain'},
          )
          .timeout(probe);
      _use(config.localUrl);
    } catch (_) {
      _use(remote);
    }
    return _activeBaseUrl;
  }

  /// Runs [attempt] on the address in use and, when it cannot be reached,
  /// once more on the other address, which is then kept.
  Future<T> _withFallback<T>(Future<T> Function(String base) attempt) async {
    final tried = _activeBaseUrl;
    try {
      return await attempt(tried);
    } on FrigateUnreachableException catch (first) {
      // Another request may have moved already; otherwise try the other one.
      final next = _activeBaseUrl != tried ? _activeBaseUrl : _alternate(tried);
      if (next == null) rethrow;
      try {
        final result = await attempt(next);
        _use(next);
        return result;
      } on FrigateUnreachableException {
        // A certificate to confirm says more than the other address failing.
        if (first is FrigateCertificateException) throw first;
        rethrow;
      }
    }
  }

  /// A TLS failure on [base]: a certificate to confirm when the local
  /// address presented one the user has not trusted.
  FrigateUnreachableException _handshakeError(
    String base,
    HandshakeException e,
    String message,
  ) {
    final fingerprint = _certificates.takeRejected();
    if (fingerprint != null && base == config.localUrl) {
      return FrigateCertificateException(
        fingerprint,
        changed: config.certFingerprint != null,
        cause: e,
      );
    }
    return FrigateUnreachableException(message, e);
  }

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setToken(String? token) {
    _token = token;
  }

  void setActiveBaseUrl(String url) {
    _activeBaseUrl = ServerConfig.normalizeUrl(url);
  }

  static http.Client _createDefaultClient(CertificateGuard certificates) {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 10);
    // Called only for certificates the system refuses: the confirmed
    // self-signed one of the local address passes, nothing else.
    httpClient.badCertificateCallback = (cert, host, port) =>
        certificates.accepts(cert.der, host, port);
    return IOClient(httpClient);
  }

  /// Closes the underlying HTTP client.
  void close() {
    _closeSocket();
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Frigate's WebSocket, opened on the first command and kept for the next
  /// ones (pan and tilt send a move, then a stop).
  WebSocket? _socket;
  Future<WebSocket>? _connecting;

  /// Opens a WebSocket on [url] with [headers]; tests replace it.
  @visibleForTesting
  Future<WebSocket> Function(Uri url, Map<String, String> headers)?
  connectSocket;

  /// What the ONVIF camera [camera] can do (`GET /api/<camera>/ptz/info`).
  Future<PtzInfo> fetchPtzInfo(String camera) async => PtzInfo.fromJson(
    await _getJson('/api/${Uri.encodeComponent(camera)}/ptz/info'),
  );

  /// Sends [payload] (`MOVE_UP`, `STOP`, `preset_<name>`…) to the camera's
  /// ONVIF control through Frigate's WebSocket.
  Future<void> sendPtz(String camera, String payload) async {
    final message = jsonEncode({'topic': '$camera/ptz', 'payload': payload});
    try {
      (await _openSocket()).add(message);
    } on StateError {
      // Closed between opening and sending: once more on a new one.
      _closeSocket();
      (await _openSocket()).add(message);
    }
  }

  Future<WebSocket> _openSocket() {
    final open = _socket;
    if (open != null && open.readyState == WebSocket.open) {
      return Future.value(open);
    }
    return _connecting ??= _connectSocket().whenComplete(
      () => _connecting = null,
    );
  }

  Future<WebSocket> _connectSocket() async {
    final base = Uri.parse(_activeBaseUrl);
    final url = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/ws',
    );
    final headers = _buildAuthHeaders()..remove('Accept');
    final WebSocket socket;
    try {
      socket = await (connectSocket ?? _defaultSocket)(
        url,
        headers,
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException catch (e) {
      throw FrigateUnreachableException('Timed out on /ws', e);
    } on WebSocketException catch (e) {
      throw FrigateNetworkException('WebSocket refused.', e);
    } on SocketException catch (e) {
      throw FrigateUnreachableException('Connection lost.', e);
    } on HandshakeException catch (e) {
      throw _handshakeError(_activeBaseUrl, e, 'Certificate refused.');
    }
    // Frigate pushes its state to every client: read and dropped.
    socket.listen(
      (_) {},
      onDone: () {
        if (identical(_socket, socket)) _socket = null;
      },
      onError: (Object _) {},
      cancelOnError: true,
    );
    _socket = socket;
    return socket;
  }

  Future<WebSocket> _defaultSocket(Uri url, Map<String, String> headers) {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (cert, host, port) =>
          _certificates.accepts(cert.der, host, port);
    return WebSocket.connect(
      url.toString(),
      headers: headers,
      customClient: httpClient,
    );
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
  }

  /// Authenticates with the server via `POST /api/login`.
  ///
  /// Extracts the session JWT from the Set-Cookie header and stores it.
  /// Tries the other address when the one in use cannot be reached.
  Future<String> login(String password) => _withFallback(
    (base) => _login(base, password),
  );

  Future<String> _login(String base, String password) async {
    final uri = Uri.parse('$base/api/login');
    final body = jsonEncode({
      'user': config.username,
      'password': password,
    });

    try {
      final response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final token = _extractTokenFromHeaders(response.headers);
        if (token != null && token.isNotEmpty) {
          _token = token;
          return token;
        }
        // Fallback: check if the body contains a token.
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['token'] is String) {
            final t = decoded['token'] as String;
            _token = t;
            return t;
          }
        } catch (_) {}
        throw const FrigateAuthException(
          'Login succeeded but no session token was returned by Frigate.',
          statusCode: 200,
        );
      }

      if (response.statusCode == 401) {
        throw const FrigateAuthException('Wrong username or password.');
      }

      throw FrigateAuthException(
        'Login refused (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on SocketException catch (e) {
      throw FrigateUnreachableException(
        'Cannot reach $base.',
        e,
      );
    } on HandshakeException catch (e) {
      throw _handshakeError(
        base,
        e,
        'TLS error at $base: a self-signed certificate is accepted on the local address only.',
      );
    } on http.ClientException catch (e) {
      throw FrigateUnreachableException(
        'Cannot reach $base.',
        e,
      );
    } on TimeoutException catch (e) {
      throw FrigateUnreachableException(
        'Timed out connecting to $base.',
        e,
      );
    }
  }

  /// Reads capabilities from the server: version, config, and go2rtc streams
  /// (decision 0002).
  Future<ServerCapabilities> fetchCapabilities() async {
    final versionFuture = _get('/api/version').catchError((_) => '');
    final configFuture = _getJson('/api/config');
    final streamsFuture = _getJson('/api/go2rtc/streams')
        .catchError((_) => <String, dynamic>{});

    final version = await versionFuture;
    final configData = await configFuture;
    final streamsData = await streamsFuture;

    return ServerCapabilities.fromJson(
      config: configData,
      streams: streamsData,
      version: version.trim(),
    );
  }

  /// Reads user profile from `GET /api/profile`.
  Future<Map<String, dynamic>> fetchProfile() async {
    return _getJson('/api/profile');
  }

  /// Performs an authenticated GET request and returns the decoded JSON map.
  Future<Map<String, dynamic>> _getJson(String path) async {
    final body = await _get(path);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const {};
    } catch (e) {
      throw FrigateNetworkException('Invalid response from $path', e);
    }
  }

  /// Reads the most recent frame of [camera] from
  /// `GET /api/<camera>/latest.jpg`, scaled by Frigate to [height] pixels
  /// when given (thumbnails), at full resolution otherwise.
  Future<Uint8List> fetchLatestImage(String camera, {int? height}) async {
    final path = Uri(
      path: '/api/${Uri.encodeComponent(camera)}/latest.jpg',
      queryParameters: height != null ? {'h': '$height'} : null,
    ).toString();
    final response = await _send(
      path,
      timeout: const Duration(seconds: 10),
      accept: 'image/jpeg',
    );
    return response.bodyBytes;
  }

  /// Reads the recorded frame of [camera] at [time] from
  /// `GET /api/<camera>/recordings/<time>/snapshot.jpg`, scaled by Frigate
  /// to [height] pixels when given.
  Future<Uint8List> fetchRecordingImage(
    String camera,
    DateTime time, {
    int? height,
  }) async {
    final path = Uri(
      path:
          '/api/${Uri.encodeComponent(camera)}/recordings/'
          '${epochSeconds(time)}/snapshot.jpg',
      queryParameters: height != null ? {'height': '$height'} : null,
    ).toString();
    final response = await _send(
      path,
      timeout: const Duration(seconds: 10),
      accept: 'image/jpeg',
    );
    return response.bodyBytes;
  }

  /// Exchanges a WebRTC offer for go2rtc's answer through Frigate's
  /// authenticated proxy, `POST /api/go2rtc/webrtc?src=<stream>`.
  ///
  /// go2rtc answers once its own ICE candidates are gathered, so the answer
  /// is complete and no trickle channel is needed.
  Future<String> negotiateWebRtc(String stream, String offerSdp) async {
    final path = Uri(
      path: '/api/go2rtc/webrtc',
      queryParameters: {'src': stream},
    ).toString();
    final response = await _send(
      path,
      body: jsonEncode({'type': 'offer', 'sdp': offerSdp}),
      timeout: const Duration(seconds: 10),
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['sdp'] is String) {
        return decoded['sdp'] as String;
      }
    } on FormatException {
      // Older go2rtc versions answer with the raw SDP.
      if (response.body.startsWith('v=')) return response.body;
    }
    throw FrigateNetworkException('Invalid WebRTC answer for $stream');
  }

  /// Reads the recorded segments of [camera] between [after] and [before]
  /// from `GET /api/<camera>/recordings`, sorted by start time.
  Future<List<RecordingSegment>> fetchRecordings(
    String camera,
    DateTime after,
    DateTime before,
  ) async {
    final path = Uri(
      path: '/api/${Uri.encodeComponent(camera)}/recordings',
      queryParameters: {
        'after': epochSeconds(after),
        'before': epochSeconds(before),
      },
    ).toString();
    final body = await _get(path);
    try {
      return parseRecordings(jsonDecode(body));
    } on FormatException catch (e) {
      throw FrigateNetworkException('Invalid response from $path', e);
    }
  }

  /// Reads the hours recorded by [camera] over its whole history from
  /// `GET /api/<camera>/recordings/summary`, asked in UTC.
  Future<List<RecordingHour>> fetchRecordingHours(String camera) async {
    final path = Uri(
      path: '/api/${Uri.encodeComponent(camera)}/recordings/summary',
      queryParameters: {'timezone': 'utc'},
    ).toString();
    final body = await _get(path);
    try {
      return parseRecordingHours(jsonDecode(body));
    } on FormatException catch (e) {
      throw FrigateNetworkException('Invalid response from $path', e);
    }
  }

  /// Reads the review items (alerts and detections) that overlap
  /// [after]..[before] from `GET /api/review`, newest first.
  Future<List<ReviewItem>> fetchReviews({
    required DateTime after,
    required DateTime before,
    ReviewSeverity? severity,
    List<String>? cameras,
    int? limit,
  }) async {
    final path = Uri(
      path: '/api/review',
      queryParameters: {
        'after': epochSeconds(after),
        'before': epochSeconds(before),
        if (severity != null) 'severity': severity.name,
        if (cameras != null && cameras.isNotEmpty) 'cameras': cameras.join(','),
        if (limit != null) 'limit': '$limit',
      },
    ).toString();
    final body = await _get(path);
    try {
      final items = parseReviews(jsonDecode(body))
        ..sort((a, b) => b.start.compareTo(a.start));
      return items;
    } on FormatException catch (e) {
      throw FrigateNetworkException('Invalid response from $path', e);
    }
  }

  /// Marks review items as seen, or not seen, for the user signed in:
  /// `POST /api/reviews/viewed`.
  Future<void> markReviewed(List<String> ids, {bool reviewed = true}) async {
    if (ids.isEmpty) return;
    await _send(
      '/api/reviews/viewed',
      body: jsonEncode({'ids': ids, 'reviewed': reviewed}),
    );
  }

  /// Reads a review thumbnail from the [path] given by [ReviewItem.thumbnail].
  Future<Uint8List> fetchReviewThumbnail(String path) async {
    final response = await _send(
      path,
      timeout: const Duration(seconds: 10),
      accept: 'image/webp,image/*',
    );
    return response.bodyBytes;
  }

  /// Opens an authenticated GET of [path] and returns the response as it
  /// arrives, whatever its status, for the VOD relay of the player.
  ///
  /// [headers] are forwarded (for instance `Range`); authentication is added.
  Future<http.StreamedResponse> openStream(
    String path, {
    Map<String, String> headers = const {},
  }) => _withFallback((base) => _openStream(base, path, headers));

  Future<http.StreamedResponse> _openStream(
    String base,
    String path,
    Map<String, String> headers,
  ) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final request = http.Request('GET', Uri.parse('$base$cleanPath'))
      ..headers.addAll(headers)
      ..headers.addAll(_buildAuthHeaders(accept: headers['Accept'] ?? '*/*'));
    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw const FrigateAuthException('Session expired or not authorized.');
      }
      return response;
    } on SocketException catch (e) {
      throw FrigateUnreachableException('Connection lost.', e);
    } on HandshakeException catch (e) {
      throw _handshakeError(base, e, 'Certificate refused.');
    } on http.ClientException catch (e) {
      throw FrigateUnreachableException('Connection lost.', e);
    } on TimeoutException catch (e) {
      throw FrigateUnreachableException('Timed out on $path', e);
    }
  }

  /// Performs an authenticated GET request and returns raw response body.
  Future<String> _get(String path) async => (await _send(path)).body;

  /// Performs an authenticated request (GET, or POST of a JSON [body]) and
  /// returns the response when it succeeded, throwing a
  /// [FrigateAuthException] or a [FrigateNetworkException] otherwise.
  Future<http.Response> _send(
    String path, {
    String? body,
    Duration timeout = const Duration(seconds: 15),
    String accept = 'application/json',
  }) => _withFallback(
    (base) => _sendTo(base, path, body: body, timeout: timeout, accept: accept),
  );

  Future<http.Response> _sendTo(
    String base,
    String path, {
    String? body,
    required Duration timeout,
    required String accept,
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$cleanPath');
    final headers = _buildAuthHeaders(accept: accept);

    try {
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(
                      uri,
                      headers: {...headers, 'Content-Type': 'application/json'},
                      body: body,
                    ))
              .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response;
      }

      if (response.statusCode == 401) {
        throw const FrigateAuthException('Session expired or not authorized.');
      }

      throw FrigateNetworkException(
        'HTTP ${response.statusCode} on $path',
      );
    } on SocketException catch (e) {
      throw FrigateUnreachableException('Connection lost.', e);
    } on HandshakeException catch (e) {
      throw _handshakeError(base, e, 'Certificate refused.');
    } on http.ClientException catch (e) {
      throw FrigateUnreachableException('Connection lost.', e);
    } on TimeoutException catch (e) {
      throw FrigateUnreachableException('Timed out on $path', e);
    }
  }

  Map<String, String> _buildAuthHeaders({String accept = 'application/json'}) {
    final headers = <String, String>{'Accept': accept};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
      headers['Cookie'] = '$_cookieName=$_token';
    }
    return headers;
  }

  /// Name of the session cookie when Frigate keeps its default
  /// (`auth.cookie_name`).
  static const defaultCookieName = 'frigate_token';

  String? _extractTokenFromHeaders(Map<String, String> headers) {
    // Check Set-Cookie (can be 'set-cookie' in lowercase).
    final rawCookie = headers['set-cookie'] ?? headers['Set-Cookie'];
    if (rawCookie == null) return null;
    final cookie = sessionCookie(rawCookie);
    if (cookie == null) return null;
    _cookieName = cookie.$1;
    return cookie.$2;
  }
}

/// The session cookie among those of a Set-Cookie header, as (name, value):
/// Frigate's default name first; a renamed one (`auth.cookie_name`) only
/// when its value is a JWT, so that no other cookie (a proxy's, say) is
/// taken for the session.
(String, String)? sessionCookie(String header) {
  final cookies = <(String, String)>[];
  // Several cookies are joined by commas; an Expires date holds one too,
  // but its pieces have no "=" before the first ";".
  for (final c in header.split(',')) {
    final pair = c.split(';').first.trim();
    final at = pair.indexOf('=');
    if (at <= 0) continue;
    final value = pair.substring(at + 1).trim();
    if (value.isEmpty) continue;
    cookies.add((pair.substring(0, at).trim(), value));
  }
  for (final c in cookies) {
    if (c.$1 == FrigateClient.defaultCookieName) return c;
  }
  final jwt = RegExp(r'^[\w-]+\.[\w-]+\.[\w-]+$');
  final tokens = cookies.where((c) => jwt.hasMatch(c.$2)).toList();
  return tokens.length == 1 ? tokens.single : null;
}
