import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/core/frigate/vod_proxy.dart';
import 'package:http/http.dart' as http;

void main() {
  late List<(String, Map<String, String>)> opened;
  late VodProxy proxy;
  var expired = false;
  var authErrors = 0;

  Future<http.StreamedResponse> open(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    opened.add((path, headers));
    if (expired) throw const FrigateAuthException('expired');
    return http.StreamedResponse(
      Stream.value(utf8.encode('#EXTM3U')),
      200,
      headers: {'content-type': 'application/vnd.apple.mpegurl'},
    );
  }

  setUp(() async {
    opened = [];
    expired = false;
    authErrors = 0;
    proxy = VodProxy(open, secret: 's3cr3t', onAuthError: () => authErrors++);
    await proxy.start();
  });

  tearDown(() => proxy.close());

  Future<(int, String, String?)> get(Uri url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      request.headers.set('range', 'bytes=0-');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      return (
        response.statusCode,
        body,
        response.headers.value('content-type'),
      );
    } finally {
      client.close();
    }
  }

  test('relays a playlist from the loopback address', () async {
    final url = proxy.playlist(
      'cam_a',
      DateTime.fromMillisecondsSinceEpoch(1000000),
      DateTime.fromMillisecondsSinceEpoch(2000000),
    );
    expect(url.host, '127.0.0.1');
    expect(url.path, '/s3cr3t/vod/cam_a/start/1000/end/2000/master.m3u8');

    final (status, body, type) = await get(url);
    expect(status, 200);
    expect(body, '#EXTM3U');
    expect(type, 'application/vnd.apple.mpegurl');
    expect(opened.single.$1, '/vod/cam_a/start/1000/end/2000/master.m3u8');
    expect(opened.single.$2['range'], 'bytes=0-');

    // Segments are relative to the playlist.
    await get(url.resolve('seg-1-v1-a1.m4s'));
    expect(opened.last.$1, '/vod/cam_a/start/1000/end/2000/seg-1-v1-a1.m4s');
  });

  test('refuses requests without the secret or outside /vod/', () async {
    final url = proxy.playlist('cam_a', DateTime(2026), DateTime(2026));
    expect((await get(url.replace(path: '/vod/cam_a/x'))).$1, 404);
    expect((await get(url.replace(path: '/s3cr3t/api/config'))).$1, 404);
    expect((await get(url.replace(path: '/s3cr3u/vod/cam_a/x'))).$1, 404);
    expect(opened, isEmpty);
  });

  test('relays nothing but recordings, even with the secret', () async {
    final url = proxy.playlist('cam_a', DateTime(2026), DateTime(2026));
    final base = 'http://127.0.0.1:${url.port}/s3cr3t';
    for (final path in const [
      '/vod/..%2F..%2Fapi%2Fconfig',
      '/vod/cam_a/start/1/end/2/..%2F..%2F..%2Fapi%2Fconfig',
      '/vod/..%2Fapi/start/1/end/2/master.m3u8',
      '/vod/cam_a/start/1/end/2/sub/master.m3u8',
      '/vod/cam_a/start/x/end/2/master.m3u8',
      '/vod/%2E%2E/start/1/end/2/master.m3u8',
    ]) {
      expect((await get(Uri.parse('$base$path'))).$1, 404, reason: path);
    }
    expect(opened, isEmpty);
  });

  test('reports an expired session', () async {
    expired = true;
    final url = proxy.playlist('cam_a', DateTime(2026), DateTime(2026));
    expect((await get(url)).$1, 502);
    expect(authErrors, 1);
  });
}
