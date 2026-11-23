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
import 'package:frigate_mobile/features/live/live_video.dart';
import 'package:frigate_mobile/features/live/photo.dart';
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

CameraCapabilities _camera(String name, {List<String>? streams}) =>
    CameraCapabilities(
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
      liveStreams: streams ?? [name],
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

/// Video whose state the test drives.
class _FakeVideo extends LiveVideo {
  @override
  final String stream;
  @override
  LiveVideoStatus status = LiveVideoStatus.connecting;
  @override
  bool hasAudio;
  bool _muted = LiveVideoDefaults.startMuted;
  bool started = false;
  bool disposed = false;

  _FakeVideo(this.stream, {this.hasAudio = false});

  @override
  bool get muted => _muted;
  @override
  set muted(bool value) {
    _muted = value;
    notifyListeners();
  }

  void play() {
    status = LiveVideoStatus.playing;
    notifyListeners();
  }

  void fail() {
    status = LiveVideoStatus.failed;
    notifyListeners();
  }

  /// Frame returned by [captureFrame]; null means capture unsupported.
  Uint8List? frame;

  @override
  Future<Uint8List?> captureFrame() async => frame;

  @override
  Future<void> start() async => started = true;

  @override
  Widget buildView(BoxFit fit) => SizedBox(key: ValueKey('video-$stream'));

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// Records saved and shared photos; fails on demand.
class _FakePhotos implements PhotoActions {
  final saved = <(String, Uint8List)>[];
  final shared = <String>[];
  bool fail = false;

  @override
  Future<void> save(Uint8List jpeg, String name) async {
    if (fail) throw Exception('gallery');
    saved.add((name, jpeg));
  }

  @override
  Future<void> share(Uint8List jpeg, String name) async => shared.add(name);
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
        _app(LiveGridScreen(cameras: cameras, fetch: server.fetch, layout: 4)),
      );
      await tester.pump();

      expect(find.byType(FeedTile), findsNWidgets(4));
      expect(server.cameras, {'cam_a', 'cam_b', 'cam_c', 'cam_d'});
      // 2 × 2 tiles of an 800 × 600 screen at 3 pixels per point.
      expect(server.calls.every((c) => c.$2 == 720), isTrue);
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
      expect(find.bySemanticsLabel(RegExp('Page')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('automatic layout fills a phone, upright or turned', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1860);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final server = _FakeServer();
      await tester.pumpWidget(
        _app(LiveGridScreen(cameras: cameras, fetch: server.fetch)),
      );
      await tester.pump();

      // Upright: every camera on one page, two columns of 4:3 tiles.
      expect(find.byType(FeedTile), findsNWidgets(6));
      expect(find.bySemanticsLabel(RegExp('Page')), findsNothing);
      final upright = tester.getSize(find.byType(FeedTile).first);
      expect(upright.width, closeTo((360 - 12 - 4) / 2, 0.01));
      expect(upright.width / upright.height, closeTo(4 / 3, 0.01));
      expect(server.calls.every((c) => c.$2 == 360), isTrue);

      // Turned: three columns, the feeds keep running.
      tester.view.physicalSize = const Size(1860, 1080);
      await tester.pump();
      await tester.pump();
      final turned = tester.getRect(find.byType(FeedTile).at(2));
      final first = tester.getRect(find.byType(FeedTile).first);
      expect(turned.top, first.top);
      server.calls.clear();
      await tester.pump(LiveDefaults.gridInterval);
      expect(server.cameras.length, 6);

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
      expect(server.cameras.length, 6);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('CameraFullScreen video', () {
    late _FakeServer server;
    late List<_FakeVideo> videos;
    late _FakePhotos photos;
    var withAudio = false;

    LiveVideo factory(String stream) {
      final video = _FakeVideo(stream, hasAudio: withAudio);
      videos.add(video);
      return video;
    }

    Future<void> open(
      WidgetTester tester,
      List<CameraCapabilities> cams, {
      bool lightStreamFirst = false,
      bool tryOtherStreams = true,
    }) => tester.pumpWidget(
      _app(
        CameraFullScreen(
          cameras: cams,
          initialCamera: cams.first.name,
          fetch: server.fetch,
          videoFactory: factory,
          photoActions: photos,
          lightStreamFirst: lightStreamFirst,
          tryOtherStreams: tryOtherStreams,
        ),
      ),
    );

    setUp(() {
      server = _FakeServer();
      videos = [];
      photos = _FakePhotos();
      withAudio = false;
    });

    testWidgets('images until the first video frame, then video only', (
      tester,
    ) async {
      withAudio = true;
      await open(tester, cameras);
      await tester.pump();

      expect(videos.single.stream, 'cam_a');
      expect(videos.single.started, isTrue);
      expect(find.text('Connexion vidéo…'), findsOneWidget);
      expect(find.byType(FeedImage), findsOneWidget);
      expect(server.calls, isNotEmpty);

      videos.single.play();
      await tester.pump();
      expect(find.text('Vidéo en direct'), findsOneWidget);
      expect(find.byType(FeedImage), findsNothing);
      expect(find.byKey(const ValueKey('video-cam_a')), findsOneWidget);

      // No more image requests while the video plays.
      server.calls.clear();
      await tester.pump(const Duration(seconds: 5));
      expect(server.calls, isEmpty);

      // Sound starts muted; the button turns it on.
      expect(videos.single.muted, isTrue);
      await tester.tap(find.byTooltip('Activer le son'));
      await tester.pump();
      expect(videos.single.muted, isFalse);
      expect(find.byTooltip('Couper le son'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(videos.single.disposed, isTrue);
    });

    testWidgets('no sound button when the stream has no sound', (
      tester,
    ) async {
      await open(tester, cameras);
      videos.single.play();
      await tester.pump();
      expect(find.byTooltip('Activer le son'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed video falls back to images and can retry', (
      tester,
    ) async {
      await open(tester, cameras);
      videos.single.play();
      await tester.pump();

      videos.single.fail();
      await tester.pump();
      expect(find.byType(FeedImage), findsOneWidget);
      expect(
        find.text('Vidéo indisponible · Images · toutes les 1 s'),
        findsOneWidget,
      );
      server.calls.clear();
      await tester.pump(const Duration(seconds: 2));
      expect(server.calls, isNotEmpty);

      await tester.tap(find.byTooltip('Réessayer la vidéo'));
      await tester.pump();
      expect(videos, hasLength(2));
      expect(videos.first.disposed, isTrue);
      expect(videos.last.started, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed stream switches to the next one, then images', (
      tester,
    ) async {
      await open(tester, [
        _camera('cam_g', streams: ['cam_g_1', 'cam_g_2', 'cam_g_3']),
      ]);
      videos.single.play();
      await tester.pump();

      // The main stream freezes: the next stream is tried.
      videos.single.fail();
      await tester.pump();
      expect(videos.map((v) => v.stream), ['cam_g_1', 'cam_g_2']);
      expect(videos.first.disposed, isTrue);
      expect(find.byType(FeedImage), findsOneWidget);
      videos.last.play();
      await tester.pump();
      expect(find.text('Vidéo en direct · Flux 2'), findsOneWidget);

      // Every stream fails in turn: images, no endless loop.
      videos.last.fail();
      await tester.pump();
      videos.last.fail();
      await tester.pump();
      expect(videos.map((v) => v.stream), ['cam_g_1', 'cam_g_2', 'cam_g_3']);
      expect(
        find.text('Vidéo indisponible · Images · toutes les 1 s'),
        findsOneWidget,
      );

      // Retry starts again from the stream last used.
      await tester.tap(find.byTooltip('Réessayer la vidéo'));
      await tester.pump();
      expect(videos.last.stream, 'cam_g_3');
      expect(videos.last.started, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('light stream first; no other stream when switched off', (
      tester,
    ) async {
      await open(
        tester,
        [
          _camera('cam_g', streams: ['cam_g_1', 'cam_g_2']),
        ],
        lightStreamFirst: true,
        tryOtherStreams: false,
      );
      expect(videos.single.stream, 'cam_g_2');
      videos.single.fail();
      await tester.pump();
      expect(videos, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('quality menu switches between the camera streams', (
      tester,
    ) async {
      await open(tester, [
        _camera('cam_g', streams: ['cam_g_1', 'cam_g_2']),
        _camera('cam_h'),
      ]);
      videos.single.play();
      await tester.pump();
      expect(find.text('Vidéo en direct · Flux 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Qualité'));
      await tester.pumpAndSettle();
      expect(find.text('Flux 1 (principal)'), findsOneWidget);
      await tester.tap(find.text('Flux 2'));
      await tester.pumpAndSettle();

      expect(videos.map((v) => v.stream), ['cam_g_1', 'cam_g_2']);
      expect(videos.first.disposed, isTrue);
      videos.last.play();
      await tester.pump();
      expect(find.text('Vidéo en direct · Flux 2'), findsOneWidget);

      // A camera with one stream has no quality menu.
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(videos.last.stream, 'cam_h');
      expect(videos[1].disposed, isTrue);
      expect(find.byTooltip('Qualité'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('photo saves the video frame and offers to share it', (
      tester,
    ) async {
      await open(tester, cameras);
      await tester.pump();
      final frame = Uint8List.fromList([9, 9, 9]);
      videos.single
        ..frame = frame
        ..play();
      await tester.pump();

      server.calls.clear();
      await tester.tap(find.text('Photo'));
      await tester.pump();
      await tester.pump();

      expect(photos.saved.single.$2, same(frame));
      expect(
        photos.saved.single.$1,
        matches(RegExp(r'^cam_a_\d{8}_\d{6}$')),
      );
      expect(server.calls, isEmpty);
      expect(
        find.text("Photo enregistrée dans l'album Frigate"),
        findsOneWidget,
      );

      // Let the snack bar slide in before tapping its action.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Partager'));
      await tester.pump();
      expect(photos.shared, [photos.saved.single.$1]);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('photo falls back to the full-size image', (tester) async {
      await open(tester, cameras);
      await tester.pump();

      // Video still connecting: the image on screen is saved.
      server.calls.clear();
      await tester.tap(find.text('Photo'));
      await tester.pump();
      await tester.pump();
      expect(server.calls, [('cam_a', null)]);
      expect(photos.saved.single.$2, _pixel);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed save says so', (tester) async {
      photos.fail = true;
      await open(tester, cameras);
      await tester.pump();
      await tester.tap(find.text('Photo'));
      await tester.pump();
      await tester.pump();
      expect(find.text("Impossible d'enregistrer la photo"), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('FrameWatch', () {
    final t0 = DateTime(2026, 1, 10, 12);
    DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

    test('a video decoding at its rate is not frozen', () {
      final watch = FrameWatch();
      for (var s = 0; s <= 20; s += 2) {
        expect(watch.frozen(at(s), s * 12), isFalse);
      }
    });

    test('no judgement before the window has passed', () {
      final watch = FrameWatch();
      expect(watch.frozen(at(0), 1), isFalse);
      expect(watch.frozen(at(4), 1), isFalse);
      expect(watch.frozen(at(6), 1), isTrue);
    });

    test('a video that stops decoding is frozen after the window', () {
      final watch = FrameWatch();
      for (var s = 0; s <= 10; s += 2) {
        expect(watch.frozen(at(s), s * 12), isFalse);
      }
      // No new frame from 10 s.
      expect(watch.frozen(at(12), 120), isFalse);
      expect(watch.frozen(at(14), 120), isFalse);
      expect(watch.frozen(at(16), 120), isTrue);
    });

    test('a few frames now and then is still frozen', () {
      final watch = FrameWatch();
      var frames = 0;
      var frozen = false;
      for (var s = 0; s <= 12; s += 2) {
        frames += s % 4 == 0 ? 1 : 0;
        frozen = watch.frozen(at(s), frames);
      }
      expect(frozen, isTrue);
    });
  });

  group('sdpHasAudio', () {
    const video = 'm=video 9 UDP/TLS/RTP/SAVPF 96\r\na=sendonly\r\n';
    test('active audio section', () {
      expect(
        sdpHasAudio(
          'v=0\r\n${video}m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'a=rtpmap:111 opus/48000/2\r\na=sendonly\r\n',
        ),
        isTrue,
      );
    });
    test('inactive, rejected or missing audio', () {
      expect(
        sdpHasAudio(
          'v=0\r\n${video}m=audio 9 UDP/TLS/RTP/SAVPF 0\r\n'
          'a=inactive\r\n',
        ),
        isFalse,
      );
      expect(
        sdpHasAudio('v=0\r\n${video}m=audio 0 UDP/TLS/RTP/SAVPF 0\r\n'),
        isFalse,
      );
      expect(sdpHasAudio('v=0\r\n$video'), isFalse);
    });
    test('audio before video', () {
      expect(
        sdpHasAudio(
          'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 8\r\n'
          'a=sendonly\r\n$video',
        ),
        isTrue,
      );
    });
  });
}
