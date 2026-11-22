import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = ServerConfig(
    name: 'Maison',
    localUrl: 'https://192.168.1.53:8971',
    username: 'cmathias',
  );

  test('login extracts frigate_token from Set-Cookie header', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/api/login');
      final body = jsonDecode(request.body) as Map;
      expect(body['user'], 'cmathias');
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
            'username': 'cmathias',
            'role': 'admin',
            'allowed_cameras': ['cam_portier'],
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
    expect(profile['username'], 'cmathias');
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
              'cam_portier': {
                'enabled': true,
                'detect': {'enabled': false},
                'record': {
                  'enabled': true,
                  'continuous': {'days': 3.0},
                },
                'live': {
                  'streams': {'Stream 1': 'cam_portier'},
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
            'cam_portier': {
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
    expect(caps.cameras['cam_portier']!.talk, isTrue);
    expect(caps.cameras['cam_portier']!.continuousDays, 3.0);
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

    final bytes = await client.fetchLatestImage('cam_portier', height: 360);

    expect(bytes, [1, 2, 3]);
    expect(sent.url.path, '/api/cam_portier/latest.jpg');
    expect(sent.url.queryParameters, {'h': '360'});
    expect(sent.headers['Accept'], 'image/jpeg');
    expect(sent.headers['Authorization'], 'Bearer jwt-img');

    await client.fetchLatestImage('cam_portier');
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
      client.fetchLatestImage('cam_portier'),
      throwsA(isA<FrigateAuthException>()),
    );
    status = 404;
    await expectLater(
      client.fetchLatestImage('cam_portier'),
      throwsA(isA<FrigateNetworkException>()),
    );
    status = 0;
    await expectLater(
      client.fetchLatestImage('cam_portier'),
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

    final answer = await client.negotiateWebRtc('cam_garage_2', 'v=0\r\noffer');

    expect(answer, 'v=0\r\nanswer');
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/go2rtc/webrtc');
    expect(sent.url.queryParameters, {'src': 'cam_garage_2'});
    expect(sent.headers['Authorization'], 'Bearer jwt-rtc');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'type': 'offer', 'sdp': 'v=0\r\noffer'});

    raw = true;
    expect(
      await client.negotiateWebRtc('cam_garage_2', 'v=0'),
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
}
