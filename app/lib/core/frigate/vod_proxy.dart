import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'client.dart' show FrigateAuthException;
import 'recordings.dart';

/// Opens an authenticated GET on Frigate (see `FrigateClient.openStream`).
typedef StreamOpener = Future<http.StreamedResponse> Function(
  String path, {
  Map<String, String> headers,
});

/// Relays Frigate's HLS recordings (`/vod/…`) to the Android player.
///
/// The system player cannot send Frigate's session nor accept the
/// self-signed certificate allowed for a local server, so it reads from this
/// relay on the loopback address, and the relay asks Frigate through the
/// app's own authenticated client (port 8971 only, decision 0004).
///
/// Other apps of the phone can reach the loopback address too: every URL
/// carries a random secret, and only recording paths
/// (`/vod/<camera>/start/<s>/end/<s>/<file>`) are relayed.
class VodProxy {
  final StreamOpener _open;
  final String _secret;

  /// Called when Frigate refuses the session.
  final void Function()? onAuthError;
  HttpServer? _server;

  VodProxy(this._open, {String? secret, this.onAuthError})
    : _secret = secret ?? _randomSecret();

  /// Starts listening on a free loopback port; does nothing if started.
  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  /// HLS playlist of [camera] from [start] to [end], served by the relay.
  Uri playlist(String camera, DateTime start, DateTime end) {
    final server = _server;
    if (server == null) throw StateError('VodProxy not started');
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path:
          '/$_secret/vod/${Uri.encodeComponent(camera)}'
          '/start/${epochSeconds(start)}/end/${epochSeconds(end)}'
          '/master.m3u8',
    );
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  /// The Frigate path asked by the player, or null when [segments] are not
  /// `<secret>/vod/<camera>/start/<s>/end/<s>/<file>`: nothing else of the
  /// server can be reached through the relay, even with the secret.
  String? _vodPath(List<String> segments) {
    if (segments.length != 8 ||
        !_sameSecret(segments[0]) ||
        segments[1] != 'vod' ||
        segments[3] != 'start' ||
        segments[5] != 'end' ||
        !_digits.hasMatch(segments[4]) ||
        !_digits.hasMatch(segments[6]) ||
        !_name.hasMatch(segments[2]) ||
        !_name.hasMatch(segments[7])) {
      return null;
    }
    return '/vod/${Uri.encodeComponent(segments[2])}'
        '/start/${segments[4]}/end/${segments[6]}/${segments[7]}';
  }

  static final _digits = RegExp(r'^\d{1,12}$');

  /// Camera names of Frigate and HLS file names: no separator, no `..`.
  static final _name = RegExp(r'^(?!\.{1,2}$)[\w.-]{1,128}$');

  /// Compares in constant time, as any app of the phone can try secrets.
  bool _sameSecret(String candidate) {
    if (candidate.length != _secret.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ _secret.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final path = request.method == 'GET'
          ? _vodPath(request.uri.pathSegments)
          : null;
      if (path == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final upstream = await _open(
        path,
        headers: {
          for (final name in const ['range', 'accept'])
            name: ?request.headers.value(name),
        },
      );
      response.statusCode = upstream.statusCode;
      for (final name in const [
        'content-type',
        'content-length',
        'content-range',
        'accept-ranges',
      ]) {
        if (upstream.headers[name] case final value?) {
          response.headers.set(name, value);
        }
      }
      await response.addStream(upstream.stream);
      await response.close();
    } catch (e) {
      if (e is FrigateAuthException) onAuthError?.call();
      // Network or session error: the player shows the failure.
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {
        // Headers already sent; the connection is simply dropped.
      }
    }
  }

  static String _randomSecret() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
