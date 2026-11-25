import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/core/frigate/ptz.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = ServerConfig(
    name: 'Maison',
    localUrl: 'https://192.168.1.10:8971',
    username: 'viewer',
  );

  test('login extracts frigate_token from Set-Cookie header', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/api/login');
      final body = jsonDecode(request.body) as Map;
      expect(body['user'], 'viewer');
      expect(body['password'], 'secret');

      return http.Response(
        '',
        200,
        headers: {
          'set-cookie': 'frigate_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test; Path=/; HttpOnly; SameSite=Lax',
        },
      );
    });

    final client = FrigateClient(config: config, client: mockClient);
    final token = await client.login('secret');

    expect(token, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test');
    expect(client.isAuthenticated, isTrue);
    expect(client.token, token);
  });

  test(
    'login throws FrigateAuthException on 401 invalid credentials',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Login failed'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = FrigateClient(config: config, client: mockClient);
      expect(
        () => client.login('wrong-pass'),
        throwsA(
          isA<FrigateAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(client.isAuthenticated, isFalse);
    },
  );

  test('authenticated request sends Bearer and Cookie headers', () async {
    late http.BaseRequest sentRequest;
    final mockClient = MockClient((request) async {
      sentRequest = request;
      if (request.url.path == '/api/profile') {
        return http.Response(
          jsonEncode({
            'username': 'viewer',
            'role': 'admin',
            'allowed_cameras': ['cam_entree'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not found', 404);
    });

    final client = FrigateClient(
      config: config,
      token: 'jwt-12345',
      client: mockClient,
    );

    final profile = await client.fetchProfile();
    expect(profile['username'], 'viewer');
    expect(profile['role'], 'admin');

    expect(sentRequest.headers['Authorization'], 'Bearer jwt-12345');
    expect(sentRequest.headers['Cookie'], 'frigate_token=jwt-12345');
  });

  test('fetchCapabilities merges version, config and streams', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/version') {
        return http.Response('0.18.3-a19e23a', 200);
      }
      if (request.url.path == '/api/config') {
        return http.Response(
          jsonEncode({
            'cameras': {
              'cam_entree': {
                'enabled': true,
                'detect': {'enabled': false},
                'record': {
                  'enabled': true,
                  'continuous': {'days': 3.0},
                },
                'live': {
                  'streams': {'Stream 1': 'cam_entree'},
                },
              },
            },
            'face_recognition': {'enabled': false},
            'lpr': {'enabled': false},
            'semantic_search': {'enabled': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/go2rtc/streams') {
        return http.Response(
          jsonEncode({
            'cam_entree': {
              'producers': [
                {
                  'medias': [
                    'video, recvonly, H264',
                    'audio, recvonly, L16/16000',
                    'audio, sendonly, L16/16000',
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not found', 404);
    });

    final client = FrigateClient(
      config: config,
      token: 'jwt-xyz',
      client: mockClient,
    );

    final caps = await client.fetchCapabilities();
    expect(caps.version, '0.18.3-a19e23a');
    expect(caps.cameras.length, 1);
    expect(caps.cameras['cam_entree']!.talk, isTrue);
    expect(caps.cameras['cam_entree']!.continuousDays, 3.0);
    expect(caps.anyObjectDetection, isFalse);
  });

  test('fetchLatestImage asks for a scaled JPEG with the token', () async {
    late http.BaseRequest sent;
    final mockClient = MockClient((request) async {
      sent = request;
      return http.Response.bytes([1, 2, 3], 200);
    });
    final client = FrigateClient(
      config: config,
      token: 'jwt-img',
      client: mockClient,
    );

    final bytes = await client.fetchLatestImage('cam_entree', height: 360);

    expect(bytes, [1, 2, 3]);
    expect(sent.url.path, '/api/cam_entree/latest.jpg');
    expect(sent.url.queryParameters, {'h': '360'});
    expect(sent.headers['Accept'], 'image/jpeg');
    expect(sent.headers['Authorization'], 'Bearer jwt-img');

    await client.fetchLatestImage('cam_entree');
    expect(sent.url.hasQuery, isFalse);
  });

  test('fetchLatestImage maps errors to Frigate exceptions', () async {
    var status = 401;
    final mockClient = MockClient((request) async {
      if (status == 0) throw http.ClientException('reset');
      return http.Response('', status);
    });
    final client = FrigateClient(
      config: config,
      token: 'x',
      client: mockClient,
    );

    await expectLater(
      client.fetchLatestImage('cam_entree'),
      throwsA(isA<FrigateAuthException>()),
    );
    status = 404;
    await expectLater(
      client.fetchLatestImage('cam_entree'),
      throwsA(isA<FrigateNetworkException>()),
    );
    status = 0;
    await expectLater(
      client.fetchLatestImage('cam_entree'),
      throwsA(isA<FrigateNetworkException>()),
    );
  });

  test('negotiateWebRtc posts the offer and returns the answer', () async {
    late http.Request sent;
    var raw = false;
    final mockClient = MockClient((request) async {
      sent = request;
      if (raw) return http.Response('v=0\r\nraw-answer', 201);
      return http.Response(
        jsonEncode({'type': 'answer', 'sdp': 'v=0\r\nanswer'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = FrigateClient(
      config: config,
      token: 'jwt-rtc',
      client: mockClient,
    );

    final answer = await client.negotiateWebRtc('cam_cour_2', 'v=0\r\noffer');

    expect(answer, 'v=0\r\nanswer');
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/go2rtc/webrtc');
    expect(sent.url.queryParameters, {'src': 'cam_cour_2'});
    expect(sent.headers['Authorization'], 'Bearer jwt-rtc');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'type': 'offer', 'sdp': 'v=0\r\noffer'});

    raw = true;
    expect(
      await client.negotiateWebRtc('cam_cour_2', 'v=0'),
      'v=0\r\nraw-answer',
    );
  });

  test('fetchRecordings asks for a time range and parses segments', () async {
    late http.BaseRequest sent;
    final mockClient = MockClient((request) async {
      sent = request;
      return http.Response(
        jsonEncode([
          {'start_time': 1000.0, 'end_time': 1010.5, 'motion': 12},
        ]),
        200,
      );
    });
    final client = FrigateClient(
      config: config,
      token: 'jwt-rec',
      client: mockClient,
    );
    final segments = await client.fetchRecordings(
      'cam_a',
      DateTime.fromMillisecondsSinceEpoch(1000000),
      DateTime.fromMillisecondsSinceEpoch(4600000),
    );
    expect(sent.url.path, '/api/cam_a/recordings');
    expect(sent.url.queryParameters, {'after': '1000', 'before': '4600'});
    expect(sent.headers['Authorization'], 'Bearer jwt-rec');
    expect(segments.single.motion, 12);
    expect(segments.single.end.millisecondsSinceEpoch, 1010500);
  });

  test('review items: listed newest first, marked seen, thumbnails', () async {
    final sent = <http.Request>[];
    final mockClient = MockClient((request) async {
      sent.add(request);
      return switch (request.url.path) {
        '/api/review' => http.Response(
          jsonEncode([
            {
              'id': 'old',
              'camera': 'cam_a',
              'start_time': 1000.0,
              'end_time': 1010.0,
              'severity': 'alert',
              'has_been_reviewed': false,
            },
            {
              'id': 'new',
              'camera': 'cam_b',
              'start_time': 2000.0,
              'end_time': 2010.0,
              'severity': 'detection',
              'has_been_reviewed': true,
            },
          ]),
          200,
        ),
        '/api/reviews/viewed' => http.Response('{"success": true}', 200),
        _ => http.Response.bytes([7, 8], 200),
      };
    });
    final client = FrigateClient(
      config: config,
      token: 'jwt-rev',
      client: mockClient,
    );
    final items = await client.fetchReviews(
      after: DateTime.fromMillisecondsSinceEpoch(500000),
      before: DateTime.fromMillisecondsSinceEpoch(3000000),
      cameras: ['cam_a', 'cam_b'],
    );
    expect(items.map((i) => i.id), ['new', 'old']);
    expect(sent.last.url.queryParameters, {
      'after': '500',
      'before': '3000',
      'cameras': 'cam_a,cam_b',
    });

    await client.markReviewed(['old', 'new']);
    expect(sent.last.method, 'POST');
    expect(jsonDecode(sent.last.body), {
      'ids': ['old', 'new'],
      'reviewed': true,
    });
    await client.markReviewed([]);
    expect(sent, hasLength(2));

    final bytes = await client.fetchReviewThumbnail('/clips/review/t.webp');
    expect(sent.last.url.path, '/clips/review/t.webp');
    expect(sent.last.headers['Authorization'], 'Bearer jwt-rev');
    expect(bytes, [7, 8]);
  });

  test('openStream forwards headers and reports an expired session', () async {
    late http.BaseRequest sent;
    var status = 206;
    final mockClient = MockClient((request) async {
      sent = request;
      return http.Response('part', status);
    });
    final client = FrigateClient(
      config: config,
      token: 'jwt-vod',
      client: mockClient,
    );
    final response = await client.openStream(
      '/vod/cam_a/start/1/end/2/master.m3u8',
      headers: {'range': 'bytes=0-3'},
    );
    expect(response.statusCode, 206);
    expect(sent.url.path, '/vod/cam_a/start/1/end/2/master.m3u8');
    expect(sent.headers['range'], 'bytes=0-3');
    expect(sent.headers['Authorization'], 'Bearer jwt-vod');
    status = 401;
    await expectLater(
      client.openStream('/vod/x'),
      throwsA(isA<FrigateAuthException>()),
    );
  });

  group('PTZ', () {
    test('info: features and presets of the camera', () async {
      late Uri asked;
      final client = FrigateClient(
        config: config,
        token: 'jwt',
        client: MockClient((request) async {
          asked = request.url;
          return http.Response(
            jsonEncode({
              'name': 'cam_entree',
              'features': ['pt', 'zoom', 'zoom-r'],
              'presets': ['porte', 'allee', ''],
            }),
            200,
          );
        }),
      );
      final info = await client.fetchPtzInfo('cam_entree');
      expect(asked.path, '/api/cam_entree/ptz/info');
      expect(info.panTilt, isTrue);
      expect(info.zoom, isTrue);
      expect(info.presets, ['porte', 'allee']);
      expect(PtzInfo.fromJson(const {}).any, isFalse);
      expect(PtzInfo.fromJson(const {'features': []}).any, isFalse);
    });

    test('commands go through one authenticated WebSocket', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final messages = <Object?>[];
      final authorizations = <String?>[];
      final received = StreamController<void>.broadcast();
      server.listen((request) async {
        authorizations.add(request.headers.value('authorization'));
        final socket = await WebSocketTransformer.upgrade(request);
        // Frigate pushes its own state; the client must not mind.
        socket.add(jsonEncode({'topic': 'camera_activity', 'payload': '{}'}));
        socket.listen((m) {
          messages.add(jsonDecode(m as String));
          received.add(null);
        });
      });
      final urls = <Uri>[];
      final client =
          FrigateClient(
              config: config,
              token: 'jwt-ptz',
              client: MockClient((_) async => http.Response('', 404)),
            )
            ..connectSocket = (url, headers) {
              urls.add(url);
              return WebSocket.connect(
                'ws://127.0.0.1:${server.port}/ws',
                headers: headers,
              );
            };

      await client.sendPtz('cam_entree', PtzMove.up.payload);
      await client.sendPtz('cam_entree', PtzMove.stop.payload);
      await client.sendPtz('cam_entree', ptzPresetPayload('porte'));
      while (messages.length < 3) {
        await received.stream.first;
      }

      expect(urls, [Uri.parse('wss://192.168.1.10:8971/ws')]);
      expect(authorizations, ['Bearer jwt-ptz']);
      expect(messages, [
        {'topic': 'cam_entree/ptz', 'payload': 'MOVE_UP'},
        {'topic': 'cam_entree/ptz', 'payload': 'STOP'},
        {'topic': 'cam_entree/ptz', 'payload': 'preset_porte'},
      ]);
      client.close();
      await server.close(force: true);
      await received.close();
    });

    test('a refused WebSocket is a network error', () async {
      final client =
          FrigateClient(
              config: config,
              token: 'jwt',
              client: MockClient((_) async => http.Response('', 404)),
            )
            ..connectSocket = (url, headers) =>
                Future.error(const WebSocketException('not upgraded'));
      await expectLater(
        client.sendPtz('cam_entree', PtzMove.left.payload),
        throwsA(isA<FrigateNetworkException>()),
      );
    });
  });

  group('session cookie', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ2aWV3ZXIifQ.c2lnbmF0dXJl';

    test("Frigate's default name, even after another cookie", () {
      expect(
        sessionCookie('csrf_token=abc; Path=/, frigate_token=$jwt; Path=/'),
        ('frigate_token', jwt),
      );
    });

    test('a renamed cookie is taken only when it holds a JWT', () {
      expect(
        sessionCookie(
          'session=xyz; Expires=Wed, 21 Oct 2026 07:28:00 GMT, '
          'nvr_token=$jwt; HttpOnly',
        ),
        ('nvr_token', jwt),
      );
      expect(sessionCookie('csrf_token=abc123; Path=/'), isNull);
      expect(sessionCookie('my_token=; Path=/'), isNull);
    });

    test('two JWTs and no default name: none is guessed', () {
      expect(sessionCookie('a=$jwt, b=$jwt'), isNull);
    });
  });

  group('local and remote addresses', () {
    const both = ServerConfig(
      name: 'Maison',
      localUrl: 'https://192.168.1.10:8971',
      remoteUrl: 'https://frigate.example.com',
      username: 'viewer',
    );

    /// Server reachable only on the hosts in [reachable].
    MockClient network(Set<String> reachable, List<Uri> asked) =>
        MockClient((request) async {
          asked.add(request.url);
          if (!reachable.contains(request.url.host)) {
            throw http.ClientException('unreachable', request.url);
          }
          if (request.url.path == '/api/login') {
            return http.Response(
              '',
              200,
              headers: {'set-cookie': 'frigate_token=jwt; Path=/'},
            );
          }
          return http.Response('{}', 200);
        });

    test('login falls back on the remote address and keeps it', () async {
      final asked = <Uri>[];
      final client = FrigateClient(
        config: both,
        client: network({'frigate.example.com'}, asked),
      );
      final moves = <String>[];
      client.onAddressChanged = moves.add;
      expect(await client.login('secret'), 'jwt');
      expect(client.activeBaseUrl, 'https://frigate.example.com');
      expect(client.usingRemote, isTrue);
      expect(moves, ['https://frigate.example.com']);
      expect(asked.map((u) => u.host), ['192.168.1.10', 'frigate.example.com']);

      asked.clear();
      await client.fetchProfile();
      expect(asked.single.host, 'frigate.example.com');
    });

    test('back on the local network, requests return to it', () async {
      final asked = <Uri>[];
      final client = FrigateClient(
        config: both,
        token: 'jwt',
        client: network({'192.168.1.10'}, asked),
        activeBaseUrl: 'https://frigate.example.com',
      );
      await client.fetchProfile();
      expect(client.activeBaseUrl, 'https://192.168.1.10:8971');
      expect(asked.last.host, '192.168.1.10');
    });

    test('resolveAddress prefers the local address when it answers', () async {
      final asked = <Uri>[];
      final reachable = {'192.168.1.10', 'frigate.example.com'};
      final client = FrigateClient(
        config: both,
        token: 'jwt',
        client: network(reachable, asked),
        activeBaseUrl: 'https://frigate.example.com',
      );
      expect(await client.resolveAddress(), 'https://192.168.1.10:8971');
      reachable.remove('192.168.1.10');
      expect(await client.resolveAddress(), 'https://frigate.example.com');
    });

    test('an HTTP error does not change address', () async {
      final asked = <Uri>[];
      final client = FrigateClient(
        config: both,
        token: 'jwt',
        client: MockClient((request) async {
          asked.add(request.url);
          return http.Response('nope', 500);
        }),
      );
      await expectLater(
        client.fetchProfile(),
        throwsA(
          isA<FrigateNetworkException>().having(
            (e) => e is FrigateUnreachableException,
            'unreachable',
            isFalse,
          ),
        ),
      );
      expect(asked, hasLength(1));
      expect(client.usingRemote, isFalse);
    });

    test('without a remote address the error is reported', () async {
      final client = FrigateClient(
        config: config,
        client: network({}, []),
      );
      await expectLater(
        client.login('secret'),
        throwsA(isA<FrigateUnreachableException>()),
      );
    });
  });
}
