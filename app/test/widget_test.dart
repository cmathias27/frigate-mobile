import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';
import 'package:frigate_mobile/core/session/session_controller.dart';
import 'package:frigate_mobile/core/storage/session_storage.dart';
import 'package:frigate_mobile/features/live/feed_tile.dart';
import 'package:frigate_mobile/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client _createFakeServer() {
  return MockClient((request) async {
    if (request.url.path == '/api/login') {
      return http.Response(
        '',
        200,
        headers: {'set-cookie': 'frigate_token=test-jwt; Path=/'},
      );
    }
    if (request.url.path == '/api/version') {
      return http.Response('0.18.3', 200);
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
            'cam_av': {
              'enabled': true,
              'detect': {'enabled': false},
              'record': {
                'enabled': true,
                'continuous': {'days': 3.0},
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
      return http.Response('{}', 200);
    }
    return http.Response('Not found', 404);
  });
}

void main() {
  testWidgets('unauthenticated session shows login screen', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final storage = SessionStorage.inMemory();
    final session = SessionController(storage: storage);
    await session.init();

    await tester.pumpWidget(FrigateMobileApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un serveur'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('successful login transitions to HomeShell with tabs', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final storage = SessionStorage.inMemory();
    final mockClient = _createFakeServer();
    final session = SessionController(
      storage: storage,
      httpClient: mockClient,
    );
    await session.init();

    await tester.pumpWidget(FrigateMobileApp(session: session));
    await tester.pumpAndSettle();

    // Fill username & password
    await tester.enterText(find.byType(TextFormField).at(3), 'admin');
    await tester.enterText(find.byType(TextFormField).at(4), 'secret');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    // Now in HomeShell
    expect(find.text('Direct'), findsWidgets);
    expect(find.text('Chronologie'), findsWidgets);
    expect(find.text('Alertes'), findsWidgets);
    expect(find.text('Plus'), findsWidgets);
    expect(find.text('2 caméras en ligne'), findsOneWidget);

    // Direct tab: one tile per camera, layout buttons in the app bar.
    expect(find.byType(FeedTile), findsNWidgets(2));
    expect(find.byTooltip('4 par page'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedTile), findsOneWidget);

    // Switch to Chronologie
    await tester.tap(find.text('Chronologie'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture · Portier'), findsOneWidget);

    // Switch to Plus (MoreScreen)
    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('v0.18.3'), findsOneWidget);
    expect(
      find.text('Mode mouvement seul (sans détection d\'objets)'),
      findsOneWidget,
    );
    expect(find.text('Rétention continu : 3 jours'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    // Tap Disconnect -> dialog -> Confirm -> returns to LoginScreen
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(
      find.text('Voulez-vous vous déconnecter de ce serveur Frigate ?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un serveur'), findsOneWidget);
  });

  testWidgets('authenticated session restores directly into HomeShell', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final storage = SessionStorage.inMemory();
    await storage.saveServerConfig(
      const ServerConfig(
        name: 'Home',
        localUrl: 'https://192.168.1.53:8971',
        username: 'admin',
      ),
    );
    await storage.saveToken('valid-jwt');

    final mockClient = _createFakeServer();
    final session = SessionController(
      storage: storage,
      httpClient: mockClient,
    );
    await session.init();

    await tester.pumpWidget(FrigateMobileApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live'), findsWidgets);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Alerts'), findsWidgets);
    expect(find.text('More'), findsWidgets);
  });
}
