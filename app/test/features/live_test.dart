import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/features/live/camera_feed.dart';
import 'package:frigate_mobile/features/live/camera_full_screen.dart';
import 'package:frigate_mobile/features/live/feed_tile.dart';
import 'package:frigate_mobile/features/live/live_grid_screen.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';

/// Smallest valid PNG (1×1, transparent): decodes in widget tests.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

CameraCapabilities _camera(String name) => CameraCapabilities(
  name: name,
  label: CameraCapabilities.defaultLabel(name),
  objectDetection: false,
  trackedObjects: const [],
  recording: true,
  continuousDays: 3,
  motionDays: 0,
  alertDays: 0,
  audioDetection: false,
  ptz: false,
  talk: false,
  sound: false,
  liveStreams: [name],
);

/// Records every frame request; fails for cameras listed in [failing].
class _FakeServer {
  final calls = <(String, int?)>[];
  final failing = <String>{};
  bool expired = false;

  Future<Uint8List> fetch(String camera, {int? height}) async {
    calls.add((camera, height));
    if (expired) throw const FrigateAuthException('expired');
    if (failing.contains(camera)) {
      throw const FrigateNetworkException('down');
    }
    return _pixel;
  }

  Set<String> get cameras => {for (final (c, _) in calls) c};
}

Widget _app(Widget child) => MaterialApp(
  theme: buildDarkTheme(),
  locale: const Locale('fr'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  final cameras = [
    for (final n in ['cam_a', 'cam_b', 'cam_c', 'cam_d', 'cam_e', 'cam_f'])
      _camera(n),
  ];

  group('CameraFeed', () {
    testWidgets('refreshes at its interval until stopped', (tester) async {
      final server = _FakeServer();
      final feed = CameraFeed(
        camera: 'cam_a',
        fetch: server.fetch,
        height: 360,
        interval: const Duration(seconds: 2),
      );

      feed.start();
      await tester.pump();
      expect(server.calls, [('cam_a', 360)]);
      expect(feed.image, isNotNull);
      expect(feed.isStale, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(server.calls.length, 2);

      feed.stop();
      await tester.pump(const Duration(seconds: 10));
      expect(server.calls.length, 2);

      feed.dispose();
    });

    testWidgets('keeps the last frame when a request fails', (tester) async {
      final server = _FakeServer();
      final feed = CameraFeed(camera: 'cam_a', fetch: server.fetch)..start();
      await tester.pump();
      final first = feed.image;

      server.failing.add('cam_a');
      await tester.pump(LiveDefaults.gridInterval);
      expect(feed.failed, isTrue);
      expect(feed.isStale, isTrue);
      expect(feed.image, same(first));

      server.failing.clear();
      await tester.pump(LiveDefaults.gridInterval);
      expect(feed.failed, isFalse);

      feed.dispose();
    });

    testWidgets('stops and reports a refused session', (tester) async {
      final server = _FakeServer()..expired = true;
      var reported = 0;
      final feed = CameraFeed(
        camera: 'cam_a',
        fetch: server.fetch,
        onAuthError: () => reported++,
      )..start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));

      expect(reported, 1);
      expect(server.calls.length, 1);
      expect(feed.isRunning, isFalse);

      feed.dispose();
    });

    testWidgets('a frame older than three intervals is stale', (
      tester,
    ) async {
      var now = DateTime(2026, 1, 1, 12);
      final feed = CameraFeed(
        camera: 'cam_a',
        fetch: (_, {height}) async => _pixel,
        clock: () => now,
      );
      expect(feed.isStale, isTrue);

      feed.start();
      await tester.pump();
      feed.stop();
      expect(feed.isStale, isFalse);

      now = now.add(LiveDefaults.gridInterval * 3);
      expect(feed.isStale, isFalse);
      now = now.add(const Duration(seconds: 4));
      expect(feed.isStale, isTrue);

      feed.dispose();
    });
  });

  group('LiveGridScreen', () {
    testWidgets('refreshes only the cameras of the visible page', (
      tester,
    ) async {
      final server = _FakeServer();
      await tester.pumpWidget(
        _app(LiveGridScreen(cameras: cameras, fetch: server.fetch)),
      );
      await tester.pump();

      expect(find.byType(FeedTile), findsNWidgets(4));
      expect(server.cameras, {'cam_a', 'cam_b', 'cam_c', 'cam_d'});
      expect(server.calls.every((c) => c.$2 == 360), isTrue);
      expect(find.text('LIVE'), findsNWidgets(4));
      expect(find.text('A'), findsOneWidget);

      // Second page: the two last cameras, the first ones stop.
      server.calls.clear();
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      server.calls.clear();
      await tester.pump(LiveDefaults.gridInterval);
      expect(server.cameras, {'cam_e', 'cam_f'});
      expect(find.bySemanticsLabel('Page 2 sur 2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layout 9 shows every camera in one page', (tester) async {
      final server = _FakeServer();
      await tester.pumpWidget(
        _app(LiveGridScreen(cameras: cameras, fetch: server.fetch, layout: 9)),
      );
      await tester.pump();

      expect(find.byType(FeedTile), findsNWidgets(6));
      expect(server.cameras.length, 6);
      expect(server.calls.every((c) => c.$2 == 240), isTrue);
      expect(find.bySemanticsLabel(RegExp('Page')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an unreachable camera says so', (tester) async {
      final server = _FakeServer()..failing.add('cam_b');
      await tester.pumpWidget(
        _app(LiveGridScreen(cameras: cameras, fetch: server.fetch)),
      );
      await tester.pump();

      expect(find.text('Image indisponible'), findsOneWidget);
      expect(find.text('FIGÉ'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no camera shows a message', (tester) async {
      await tester.pumpWidget(
        _app(LiveGridScreen(cameras: const [], fetch: _FakeServer().fetch)),
      );
      expect(find.text('Aucune caméra active sur ce serveur.'), findsOneWidget);
    });

    testWidgets('a tap opens the full screen at full resolution', (
      tester,
    ) async {
      final server = _FakeServer();
      await tester.pumpWidget(
        _app(LiveGridScreen(cameras: cameras, fetch: server.fetch)),
      );
      await tester.pump();

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraFullScreen), findsOneWidget);
      expect(find.text('Images · toutes les 1 s'), findsOneWidget);

      // Only the opened camera refreshes, every second, without `h`.
      server.calls.clear();
      await tester.pump(const Duration(seconds: 3));
      expect(server.calls, everyElement(('cam_c', null)));
      expect(server.calls.length, inInclusiveRange(2, 3));

      // Swipe to the next camera.
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('D'), findsOneWidget);

      // Back to the grid: thumbnails refresh again.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      server.calls.clear();
      await tester.pump(LiveDefaults.gridInterval);
      expect(server.cameras, {'cam_a', 'cam_b', 'cam_c', 'cam_d'});

      await tester.pumpWidget(const SizedBox());
    });
  });
}
