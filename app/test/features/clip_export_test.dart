import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/features/timeline/clip_export.dart';
import 'package:frigate_mobile/features/timeline/clip_sheet.dart';
import 'package:frigate_mobile/features/timeline/motion_passages.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

final _t = DateTime(2026, 1, 10, 12);
final _edge = DateTime(2026, 1, 10, 13);

ClipRange _r(int fromSeconds, int toSeconds) => (
  start: _t.add(Duration(seconds: fromSeconds)),
  end: _t.add(Duration(seconds: toSeconds)),
);

/// Frigate's clip endpoint: answers [status] with [chunks], or keeps the
/// stream open until closed when [hold] is set.
class _FakeClips {
  int status = 200;
  List<List<int>> chunks = [
    [1, 2, 3],
    [4, 5],
  ];
  bool hold = false;
  bool expired = false;
  final paths = <String>[];
  StreamController<List<int>>? held;

  Future<http.StreamedResponse> open(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    paths.add(path);
    if (expired) throw const FrigateAuthException('expired');
    if (hold) {
      final controller = held = StreamController<List<int>>();
      for (final c in chunks) {
        controller.add(c);
      }
      return http.StreamedResponse(controller.stream, status);
    }
    return http.StreamedResponse(Stream.fromIterable(chunks), status);
  }
}

class _FakeVideos implements VideoActions {
  final saved = <String>[];
  final shared = <String>[];

  @override
  Future<void> save(File mp4) async => saved.add(mp4.path);

  @override
  Future<void> share(File mp4) async => shared.add(mp4.path);
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
  group('clip range', () {
    test('defaults to the passage played, else around the playhead', () {
      final passage = MotionPassage(
        camera: 'cam_entree',
        start: _t,
        end: _t.add(const Duration(seconds: 42)),
        peak: 50,
      );
      expect(
        defaultClipRange(
          _t.add(const Duration(seconds: 5)),
          passage: passage,
          liveEdge: _edge,
        ),
        _r(0, 42),
      );
      expect(defaultClipRange(_t, liveEdge: _edge), _r(-15, 15));
    });

    test('never past the live edge nor too long or short', () {
      expect(defaultClipRange(_edge, liveEdge: _edge), (
        start: _edge.subtract(const Duration(seconds: 15)),
        end: _edge,
      ));
      expect(clampClip(_r(0, 3600), liveEdge: _edge), _r(0, 600));
      expect(clampClip(_r(10, 10), liveEdge: _edge), _r(8, 10));
    });

    test('presets are centred on the playhead', () {
      expect(
        presetClip(_t, const Duration(minutes: 1), liveEdge: _edge),
        _r(-30, 30),
      );
      expect(
        presetClip(_edge, const Duration(seconds: 30), liveEdge: _edge),
        (start: _edge.subtract(const Duration(seconds: 30)), end: _edge),
      );
    });

    test('path in epoch seconds', () {
      final s = _t.millisecondsSinceEpoch ~/ 1000;
      expect(
        clipPath('cam_entree', _r(0, 30)),
        '/api/cam_entree/start/$s/end/${s + 30}/clip.mp4',
      );
    });
  });

  group('download', () {
    late Directory cache;
    late _FakeClips clips;
    setUp(() {
      cache = Directory.systemTemp.createTempSync('fm_clip');
      clips = _FakeClips();
    });
    tearDown(() => cache.deleteSync(recursive: true));

    Future<File> download({ClipCancelToken? cancel, List<int>? progress}) =>
        downloadClip(
          open: clips.open,
          camera: 'cam_entree',
          range: _r(0, 30),
          cache: cache,
          name: 'cam_entree_20260110_120000',
          cancel: cancel,
          onProgress: progress?.add,
        );

    test('writes the clip and drops the one kept before', () async {
      final old = File('${cache.path}/clips/old.mp4')
        ..createSync(recursive: true);
      final progress = <int>[];
      final file = await download(progress: progress);
      expect(file.path, endsWith('/clips/cam_entree_20260110_120000.mp4'));
      expect(file.readAsBytesSync(), [1, 2, 3, 4, 5]);
      expect(progress, [3, 5]);
      expect(old.existsSync(), isFalse);
    });

    test('an empty clip is an error and leaves nothing', () async {
      clips.chunks = [];
      await expectLater(download(), throwsA(isA<FrigateNetworkException>()));
      expect(Directory('${cache.path}/clips').listSync(), isEmpty);
    });

    test('a refusal is reported', () async {
      clips.status = 403;
      await expectLater(download(), throwsA(isA<FrigateAuthException>()));
      clips.status = 500;
      await expectLater(download(), throwsA(isA<FrigateNetworkException>()));
      clips
        ..status = 200
        ..expired = true;
      await expectLater(download(), throwsA(isA<FrigateAuthException>()));
    });

    test('cancelling stops and removes the partial file', () async {
      clips.hold = true;
      final cancel = ClipCancelToken();
      final progress = <int>[];
      final future = download(cancel: cancel, progress: progress);
      while (progress.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      cancel.cancel();
      await expectLater(future, throwsA(isA<ClipCancelled>()));
      expect(Directory('${cache.path}/clips').listSync(), isEmpty);
      await clips.held!.close();
    });
  });

  group('sheet', () {
    late Directory cache;
    late _FakeClips clips;
    late _FakeVideos videos;
    var authErrors = 0;
    setUp(() {
      cache = Directory.systemTemp.createTempSync('fm_clip');
      clips = _FakeClips();
      videos = _FakeVideos();
      authErrors = 0;
    });
    tearDown(() => cache.deleteSync(recursive: true));

    Future<void> pumpSheet(WidgetTester tester, {MotionPassage? passage}) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        _app(
          ClipSheet(
            export: RecordingExport(
              open: clips.open,
              frame: (camera, time) async => Uint8List(0),
              cacheDirectory: () async => cache,
              videos: videos,
              onAuthError: () => authErrors++,
            ),
            camera: 'cam_entree',
            label: 'Entrée',
            playhead: _t,
            liveEdge: _edge,
            passage: passage,
          ),
        ),
      );
    }

    testWidgets('adjusts the range and saves the clip', (tester) async {
      await pumpSheet(tester);
      expect(find.text('Extrait · Entrée'), findsOneWidget);
      expect(find.text('11:59:45'), findsOneWidget);
      expect(find.text('12:00:15'), findsOneWidget);
      expect(find.text('Durée\u00a0: 30\u00a0s'), findsOneWidget);

      await tester.tap(find.byTooltip('10\u00a0s plus tôt').first);
      await tester.pump();
      expect(find.text('11:59:35'), findsOneWidget);
      expect(find.text('Durée\u00a0: 40\u00a0s'), findsOneWidget);

      await tester.tap(find.text('5\u00a0min 00'));
      await tester.pump();
      expect(find.text('11:57:30'), findsOneWidget);
      expect(find.text('12:02:30'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        for (var i = 0; i < 20 && videos.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(videos.saved.single, endsWith('cam_entree_20260110_115730.mp4'));
      final s = _t.millisecondsSinceEpoch ~/ 1000;
      expect(
        clips.paths.single,
        '/api/cam_entree/start/${s - 150}'
        '/end/${s + 150}/clip.mp4',
      );
    });

    testWidgets('offers the passage and shares', (tester) async {
      await pumpSheet(
        tester,
        passage: MotionPassage(
          camera: 'cam_entree',
          start: _t.subtract(const Duration(seconds: 20)),
          end: _t.add(const Duration(seconds: 25)),
          peak: 60,
        ),
      );
      expect(find.text('Durée\u00a0: 45\u00a0s'), findsOneWidget);
      await tester.tap(find.text('30\u00a0s'));
      await tester.pump();
      expect(find.text('Durée\u00a0: 30\u00a0s'), findsOneWidget);
      await tester.tap(find.text('Passage'));
      await tester.pump();
      expect(find.text('Durée\u00a0: 45\u00a0s'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Partager'));
        for (var i = 0; i < 20 && videos.shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(videos.shared, hasLength(1));
      expect(videos.saved, isEmpty);
    });

    testWidgets('an expired session is reported', (tester) async {
      clips.expired = true;
      await pumpSheet(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(authErrors, 1);
      expect(
        find.text("L'extrait n'a pas pu être téléchargé."),
        findsOneWidget,
      );
      expect(videos.saved, isEmpty);
    });

    testWidgets('the end never goes past the live edge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ClipSheet(
            export: RecordingExport(
              open: clips.open,
              frame: (camera, time) async => Uint8List(0),
              cacheDirectory: () async => cache,
              videos: videos,
            ),
            camera: 'cam_entree',
            label: 'Entrée',
            playhead: _edge,
            liveEdge: _edge,
          ),
        ),
      );
      final later = find.byTooltip('10\u00a0s plus tard').last;
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: later, matching: find.byType(IconButton)).first,
            )
            .onPressed,
        isNull,
      );
    });
  });
}
