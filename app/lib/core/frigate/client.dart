import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'capabilities.dart';
import 'recordings.dart';
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

/// HTTP client for interacting with a Frigate NVR server on port 8971
/// (decision 0004).
///
/// Port 5000 is intentionally unsupported to enforce authenticated access.
class FrigateClient {
  final ServerConfig config;
  final http.Client _client;
  final bool _ownsClient;

  String? _token;
  String _cookieName = 'frigate_token';
  String _activeBaseUrl;

  FrigateClient({
    required this.config,
    this._token,
    http.Client? client,
    String? activeBaseUrl,
  }) : _client = client ?? _createDefaultClient(config),
       _ownsClient = client == null,
       _activeBaseUrl = activeBaseUrl ?? config.localUrl;

  String get activeBaseUrl => _activeBaseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setToken(String? token) {
    _token = token;
  }

  void setActiveBaseUrl(String url) {
    _activeBaseUrl = ServerConfig.normalizeUrl(url);
  }

  static http.Client _createDefaultClient(ServerConfig config) {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 10);

    if (config.allowSelfSignedCert) {
      httpClient.badCertificateCallback = (cert, host, port) {
        // Accept self-signed certificate only if the host is a local/private address.
        return ServerConfig.isLocalAddress('https://$host:$port');
      };
    }

    return IOClient(httpClient);
  }

  /// Closes the underlying HTTP client.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Authenticates with the server via `POST /api/login`.
  ///
  /// Extracts the session JWT from the Set-Cookie header and stores it.
  Future<String> login(String password) async {
    final uri = Uri.parse('$_activeBaseUrl/api/login');
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
        );
      }

      if (response.statusCode == 401) {
        throw const FrigateAuthException(
          'Identifiant ou mot de passe incorrect.',
          statusCode: 401,
        );
      }

      throw FrigateAuthException(
        'Erreur serveur lors de la connexion (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on SocketException catch (e) {
      throw FrigateNetworkException(
        'Impossible de joindre le serveur à $_activeBaseUrl. Vérifiez l\'adresse et le réseau.',
        e,
      );
    } on HandshakeException catch (e) {
      throw FrigateNetworkException(
        'Erreur TLS/certificat. Si le certificat est auto-signé, activez l\'option.',
        e,
      );
    } on TimeoutException catch (e) {
      throw FrigateNetworkException('Délai de connexion dépassé.', e);
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
      throw FrigateNetworkException('Réponse invalide reçue de $path', e);
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
    throw FrigateNetworkException('Réponse WebRTC invalide pour $stream');
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
      throw FrigateNetworkException('Réponse invalide reçue de $path', e);
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
      throw FrigateNetworkException('Réponse invalide reçue de $path', e);
    }
  }

  /// Opens an authenticated GET of [path] and returns the response as it
  /// arrives, whatever its status, for the VOD relay of the player.
  ///
  /// [headers] are forwarded (for instance `Range`); authentication is added.
  Future<http.StreamedResponse> openStream(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final request = http.Request('GET', Uri.parse('$_activeBaseUrl$cleanPath'))
      ..headers.addAll(headers)
      ..headers.addAll(_buildAuthHeaders(accept: headers['Accept'] ?? '*/*'));
    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw const FrigateAuthException('Session expirée ou non autorisée.');
      }
      return response;
    } on SocketException catch (e) {
      throw FrigateNetworkException('Connexion interrompue.', e);
    } on HandshakeException catch (e) {
      throw FrigateNetworkException('Certificat refusé.', e);
    } on http.ClientException catch (e) {
      throw FrigateNetworkException('Connexion interrompue.', e);
    } on TimeoutException catch (e) {
      throw FrigateNetworkException('Délai dépassé pour $path', e);
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
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_activeBaseUrl$cleanPath');
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
        throw const FrigateAuthException('Session expirée ou non autorisée.');
      }

      throw FrigateNetworkException(
        'Erreur HTTP ${response.statusCode} sur $path',
      );
    } on SocketException catch (e) {
      throw FrigateNetworkException('Connexion interrompue.', e);
    } on HandshakeException catch (e) {
      throw FrigateNetworkException('Certificat refusé.', e);
    } on http.ClientException catch (e) {
      throw FrigateNetworkException('Connexion interrompue.', e);
    } on TimeoutException catch (e) {
      throw FrigateNetworkException('Délai dépassé pour $path', e);
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

  String? _extractTokenFromHeaders(Map<String, String> headers) {
    // Check Set-Cookie (can be 'set-cookie' in lowercase).
    final rawCookie = headers['set-cookie'] ?? headers['Set-Cookie'];
    if (rawCookie == null) return null;

    // Format: "frigate_token=<jwt>; Path=/; HttpOnly; SameSite=Lax"
    final cookies = rawCookie.split(',');
    for (final c in cookies) {
      final parts = c.split(';').first.trim().split('=');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim();
        if (name == 'frigate_token' || name.contains('token')) {
          _cookieName = name;
          return value;
        }
      }
    }
    return null;
  }
}
