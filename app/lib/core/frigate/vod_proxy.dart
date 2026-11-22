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
/// carries a random secret, and only `/vod/` paths are relayed.
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

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final prefix = '/$_secret/vod/';
    final path = request.uri.path;
    try {
      if (request.method != 'GET' || !path.startsWith(prefix)) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final upstream = await _open(
        '/vod/${path.substring(prefix.length)}',
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
