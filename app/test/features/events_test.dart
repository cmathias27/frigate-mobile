import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/formatting.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';
import 'package:frigate_mobile/core/frigate/recordings.dart';
import 'package:frigate_mobile/core/storage/preferences.dart';
import 'package:frigate_mobile/features/events/events_screen.dart';
import 'package:frigate_mobile/features/events/motion_list.dart';
import 'package:frigate_mobile/features/events/thumbnails.dart';
import 'package:frigate_mobile/features/timeline/motion_passages.dart';
import 'package:frigate_mobile/features/timeline/timeline_data.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';

// Local time on an hour boundary in every time zone used by the tests.
final _now = DateTime.utc(2026, 1, 10, 12, 20).toLocal();

/// Segments every 10 s with a quiet motion, and [spikes] above it.
List<RecordingSegment> _recording(
  DateTime from,
  DateTime to, {
  Set<DateTime> spikes = const {},
}) => [
  for (var t = from; t.isBefore(to); t = t.add(const Duration(seconds: 10)))
    RecordingSegment(
      start: t,
      end: t.add(const Duration(seconds: 10)),
      motion: spikes.contains(t) ? 90 : 1,
    ),
];

class _FakeRecordings {
  final Map<String, List<RecordingSegment>> byCamera;
  final hours = <(String, DateTime)>[];
  bool failing = false;

  _FakeRecordings(this.byCamera);

  Future<List<RecordingSegment>> fetch(
    String camera,
    DateTime after,
    DateTime before,
  ) async {
    hours.add((camera, after));
    if (failing) throw Exception('offline');
    return [
      for (final s in byCamera[camera] ?? const <RecordingSegment>[])
        if (s.end.isAfter(after) && s.start.isBefore(before)) s,
    ];
  }
}

CameraCapabilities _camera(String name, String label) => CameraCapabilities(
  name: name,
  label: label,
  objectDetection: false,
  trackedObjects: const [],
  recording: true,
  continuousDays: 1,
  motionDays: 0,
  alertDays: 0,
  audioDetection: false,
  ptz: false,
  talk: false,
  sound: false,
  liveStreams: [name],
);

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
  late _FakeRecordings server;
  late TimelineData data;
  late Preferences preferences;
  var now = _now;
  final hour = DateTime.utc(2026, 1, 10, 12).toLocal();
  // Two passages in the hour being recorded, one in the hour before last,
  // and one beyond the first page of three hours.
  final recent = hour.add(const Duration(minutes: 10));
  final recentB = hour.add(const Duration(minutes: 5));
  final older = hour.subtract(const Duration(hours: 1, minutes: 30));
  final oldest = hour.subtract(const Duration(hours: 4, minutes: 30));

  MotionList list() => MotionList(
    data: data,
    history: const Duration(days: 1),
    preferences: preferences,
    clock: () => now,
  );

  setUp(() {
    now = _now;
    final from = _now.subtract(const Duration(days: 2));
    server = _FakeRecordings({
      'cam_a': _recording(from, _now, spikes: {recent, older, oldest}),
      'cam_b': _recording(from, _now, spikes: {recentB}),
    });
    data = TimelineData(
      cameras: ['cam_a', 'cam_b'],
      fetch: server.fetch,
      clock: () => now,
    );
    preferences = Preferences.inMemory();
  });

  tearDown(() => data.dispose());

  group('MotionList', () {
    test('reads the last hours of every camera, newest first', () async {
      final motion = list();
      await motion.open();
      expect(motion.from, hour.subtract(const Duration(hours: 2)));
      expect(server.hours.map((h) => h.$2).toSet(), hasLength(3));
      expect(motion.passages.map((p) => (p.camera, p.start)), [
        ('cam_a', recent),
        ('cam_b', recentB),
        ('cam_a', older),
      ]);
      expect(motion.failed, isFalse);
      expect(motion.reachedEnd, isFalse);

      await motion.loadMore();
      expect(motion.passages.last.start, oldest);

      motion.camera = 'cam_b';
      expect(motion.passages.single.start, recentB);
      motion.dispose();
    });

    test('nothing new at the first visit, then what came after', () async {
      final first = list();
      await first.open();
      expect(first.newCount, 0);
      await first.markSeen();
      first.dispose();

      // A new passage later, in a new hour.
      final later = hour.add(const Duration(hours: 1, minutes: 2));
      server.byCamera['cam_b'] = [
        ...server.byCamera['cam_b']!,
        ..._recording(
          _now,
          later.add(const Duration(minutes: 1)),
          spikes: {later},
        ),
      ];
      now = later.add(const Duration(minutes: 1));
      final second = list();
      await second.open();
      expect(second.passages.first.start, later);
      expect(second.isNew(second.passages.first), isTrue);
      expect(second.newCount, 1);
      second.dispose();
    });

    test('stops at the oldest recording kept', () async {
      final motion = MotionList(
        data: data,
        history: const Duration(hours: 4),
        preferences: preferences,
        clock: () => now,
      );
      await motion.open();
      await motion.loadMore();
      expect(motion.reachedEnd, isTrue);
      final asked = server.hours.length;
      await motion.loadMore();
      expect(server.hours, hasLength(asked));
      motion.dispose();
    });

    test('a failure is reported and retried', () async {
      server.failing = true;
      final motion = list();
      await motion.open();
      expect(motion.failed, isTrue);
      expect(motion.from, isNull);

      server.failing = false;
      // Failed hours are asked again after a delay.
      now = now.add(TimelineDefaults.retryDelay);
      await motion.retry();
      expect(motion.failed, isFalse);
      expect(motion.passages, hasLength(3));
      motion.dispose();
    });
  });

  test('passage lengths', () {
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(formatDuration(const Duration(seconds: 42), l), '42 s');
    expect(formatDuration(const Duration(seconds: 65), l), '1 min 05');
    expect(
      formatDuration(const Duration(hours: 2, minutes: 3), l),
      '2 h 03',
    );
  });

  test('thumbnails are fetched once and a failure is asked again', () async {
    var calls = 0;
    var fail = true;
    final thumbnails = RecordingThumbnails((camera, time) async {
      calls++;
      if (fail) throw Exception('offline');
      return Uint8List(1);
    }, kept: 2);
    await expectLater(thumbnails.of('cam_a', _now), throwsException);
    fail = false;
    await thumbnails.of('cam_a', _now);
    await thumbnails.of('cam_a', _now);
    expect(calls, 2);
    await thumbnails.of('cam_b', _now);
    await thumbnails.of('cam_c', _now);
    await thumbnails.of('cam_a', _now);
    expect(calls, 5);
  });

  testWidgets('lists the passages by day and opens one', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final motion = list();
    addTearDown(motion.dispose);
    MotionPassage? opened;
    await tester.pumpWidget(
      _app(
        EventsScreen(
          cameras: [_camera('cam_a', 'Entrée'), _camera('cam_b', 'Cour')],
          list: motion,
          thumbnails: RecordingThumbnails(
            (camera, time) async => Uint8List(0),
          ),
          onOpen: (p) => opened = p,
          clock: () => now,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text("AUJOURD'HUI"), findsOneWidget);
    expect(find.text('Mouvement · Entrée'), findsNWidgets(2));
    expect(find.text('Mouvement · Cour'), findsOneWidget);
    expect(find.text('Voir les 3 heures précédentes'), findsOneWidget);
    expect(find.text('Toutes caméras'), findsOneWidget);

    // The test font is wide: the chip is past the screen edge.
    await tester.dragUntilVisible(
      find.widgetWithText(ChoiceChip, 'Cour'),
      find.byType(ListView).first,
      const Offset(-200, 0),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cour'));
    await tester.pump();
    expect(find.text('Mouvement · Entrée'), findsNothing);

    await tester.tap(find.text('Mouvement · Cour'));
    expect(opened?.camera, 'cam_b');
    expect(opened?.start, recentB);
  });
}
