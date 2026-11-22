import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';
import 'package:frigate_mobile/core/session/session_controller.dart';
import 'package:frigate_mobile/core/storage/session_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const testConfig = ServerConfig(
    name: 'Maison',
    localUrl: 'https://192.168.1.53:8971',
    username: 'admin',
  );

  http.Client createMockServer({
    bool validAuth = true,
    bool networkError = false,
  }) {
    return MockClient((request) async {
      if (networkError) {
        throw http.ClientException('Network unreachable');
      }
      if (request.url.path == '/api/login') {
        if (!validAuth) {
          return http.Response(
            jsonEncode({'message': 'Login failed'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '',
          200,
          headers: {'set-cookie': 'frigate_token=new-jwt; Path=/'},
        );
      }
      if (request.url.path == '/api/version') {
        return http.Response('0.18.3', 200);
      }
      if (request.url.path == '/api/config') {
        if (!validAuth) {
          return http.Response('Unauthorized', 401);
        }
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
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/go2rtc/streams') {
        return http.Response('{}', 200);
      }
      return http.Response('Not found', 404);
    });
  }

  test('init on empty storage sets status to unauthenticated', () async {
    final storage = SessionStorage.inMemory();
    final controller = SessionController(storage: storage);

    expect(controller.status, SessionStatus.initializing);
    await controller.init();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.isAuthenticated, isFalse);
    expect(controller.config, isNull);
  });

  test('init with valid saved session restores authenticated state', () async {
    final storage = SessionStorage.inMemory();
    await storage.saveServerConfig(testConfig);
    await storage.saveToken('jwt-existing');

    final mockClient = createMockServer(validAuth: true);
    final controller = SessionController(
      storage: storage,
      httpClient: mockClient,
    );

    await controller.init();

    expect(controller.status, SessionStatus.authenticated);
    expect(controller.isAuthenticated, isTrue);
    expect(controller.capabilities?.cameras.length, 1);
    expect(controller.capabilities?.version, '0.18.3');
  });

  test('init with expired token resets session to unauthenticated', () async {
    final storage = SessionStorage.inMemory();
    await storage.saveServerConfig(testConfig);
    await storage.saveToken('jwt-expired');

    final mockClient = createMockServer(validAuth: false);
    final controller = SessionController(
      storage: storage,
      httpClient: mockClient,
    );

    await controller.init();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.isAuthenticated, isFalse);
    expect(await storage.loadToken(), isNull);
    expect(controller.errorMessage, contains('expirée'));
  });

  test('login saves config and token on success', () async {
    final storage = SessionStorage.inMemory();
    final mockClient = createMockServer(validAuth: true);
    final controller = SessionController(
      storage: storage,
      httpClient: mockClient,
    );

    final success = await controller.login(
      config: testConfig,
      password: 'good-password',
    );

    expect(success, isTrue);
    expect(controller.status, SessionStatus.authenticated);
    expect(controller.isAuthenticated, isTrue);
    expect(await storage.loadToken(), 'new-jwt');
    expect((await storage.loadServerConfig())?.name, 'Maison');
  });

  test('login handles invalid credentials gracefully', () async {
    final storage = SessionStorage.inMemory();
    final mockClient = createMockServer(validAuth: false);
    final controller = SessionController(
      storage: storage,
      httpClient: mockClient,
    );

    final success = await controller.login(
      config: testConfig,
      password: 'bad-password',
    );

    expect(success, isFalse);
    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.isAuthenticated, isFalse);
    expect(controller.errorMessage, contains('incorrect'));
    expect(await storage.loadToken(), isNull);
  });

  test('disconnect clears token and sets unauthenticated', () async {
    final storage = SessionStorage.inMemory();
    await storage.saveServerConfig(testConfig);
    await storage.saveToken('jwt-existing');

    final controller = SessionController(storage: storage);
    await controller.disconnect();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.isAuthenticated, isFalse);
    expect(await storage.loadToken(), isNull);
    expect(await storage.loadServerConfig(), isNotNull);
  });

  test('deleteServer clears both config and token', () async {
    final storage = SessionStorage.inMemory();
    await storage.saveServerConfig(testConfig);
    await storage.saveToken('jwt-existing');

    final controller = SessionController(storage: storage);
    await controller.deleteServer();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(await storage.loadToken(), isNull);
    expect(await storage.loadServerConfig(), isNull);
  });

  test('sessionExpired returns to login and keeps the server', () async {
    final storage = SessionStorage.inMemory();
    await storage.saveServerConfig(testConfig);
    await storage.saveToken('jwt-existing');
    final controller = SessionController(
      storage: storage,
      httpClient: createMockServer(),
    );
    await controller.init();
    expect(controller.isAuthenticated, isTrue);

    await controller.sessionExpired();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.client, isNull);
    expect(controller.errorMessage, contains('expirée'));
    expect(await storage.loadToken(), isNull);
    expect(await storage.loadServerConfig(), isNotNull);

    // A second report from another camera changes nothing.
    await controller.sessionExpired();
    expect(controller.status, SessionStatus.unauthenticated);
  });
}
