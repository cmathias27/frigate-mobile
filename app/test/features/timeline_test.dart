import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/core/frigate/recordings.dart';
import 'package:frigate_mobile/features/timeline/motion_passages.dart';
import 'package:frigate_mobile/features/timeline/recording_player.dart';
import 'package:frigate_mobile/features/timeline/timeline_data.dart';
import 'package:frigate_mobile/features/timeline/timeline_screen.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';

final _now = DateTime(2026, 1, 10, 12);

RecordingSegment _seg(DateTime start, int motion, {int seconds = 10}) =>
    RecordingSegment(
      start: start,
      end: start.add(Duration(seconds: seconds)),
      motion: motion,
    );

/// Segments every 10 s from [from] to [to] with a [base] motion, and
/// [spikes] (start → motion) replacing it.
List<RecordingSegment> _recording(
  DateTime from,
  DateTime to, {
  int base = 0,
  Map<DateTime, int> spikes = const {},
}) => [
  for (var t = from; t.isBefore(to); t = t.add(const Duration(seconds: 10)))
    _seg(t, spikes[t] ?? base),
];

/// Serves fixed recordings per camera and records the hours asked.
class _FakeRecordings {
  final Map<String, List<RecordingSegment>> byCamera;
  final calls = <(String, DateTime)>[];
  bool expired = false;

  _FakeRecordings(this.byCamera);

  Future<List<RecordingSegment>> fetch(
    String camera,
    DateTime after,
    DateTime before,
  ) async {
    calls.add((camera, after));
    if (expired) throw const FrigateAuthException('expired');
    return [
      for (final s in byCamera[camera] ?? const <RecordingSegment>[])
        if (!s.end.isBefore(after) && !s.start.isAfter(before)) s,
    ];
  }
}

class _FakePlayer extends RecordingPlayer {
  final opened = <(String, DateTime, DateTime)>[];
  final seeks = <DateTime>[];
  @override
  PlayerStatus status = PlayerStatus.idle;
  @override
  String? camera;
  @override
  DateTime? start;
  @override
  DateTime? end;
  @override
  DateTime? time;
  @override
  bool playing = false;
  @override
  bool completed = false;
  bool disposed = false;

  @override
  Future<void> open(String camera, DateTime start, DateTime end) async {
    opened.add((camera, start, end));
    this.camera = camera;
    this.start = start;
    this.end = end;
    time = start;
    playing = false;
    status = PlayerStatus.ready;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(DateTime time) async {
    seeks.add(time);
    this.time = time;
    notifyListeners();
  }

  @override
  Widget buildView() => const SizedBox(key: ValueKey('player'));

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

CameraCapabilities _camera(String name, String label) => CameraCapabilities(
  name: name,
  label: label,
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
  group('recordings', () {
    test('parseRecordings sorts and skips unusable items', () {
      final segments = parseRecordings([
        {'start_time': 20, 'end_time': 30.5, 'motion': 4},
        {'start_time': 10, 'end_time': 20, 'motion': 0},
        {'start_time': 'x', 'end_time': 20},
        {'start_time': 40, 'end_time': 30},
        'nope',
      ]);
      expect(segments.map((s) => s.start.millisecondsSinceEpoch), [
        10000,
        20000,
      ]);
      expect(segments.last.end.millisecondsSinceEpoch, 30500);
      expect(segments.last.motion, 4);
      expect(parseRecordings({'not': 'a list'}), isEmpty);
    });
  });

  group('motion passages', () {
    test('threshold follows the camera, never below the floor', () {
      expect(passageThreshold([0, 0, 0, 2, 3]), 10);
      // q1 10, q3 30: 30 + 1.5 × 20.
      final noisy = [0, 10, 20, 30, 40];
      expect(passageThreshold(noisy), 60);
      expect(passageThreshold(<int>[]), 10);
      expect(
        passageThreshold(noisy, const PassageSettings(threshold: 25)),
        25,
      );
    });

    test('runs above the threshold are merged within the gap', () {
      final t0 = _now;
      final segments = [
        _seg(t0, 50),
        _seg(t0.add(const Duration(seconds: 10)), 80),
        _seg(t0.add(const Duration(seconds: 20)), 2),
        // 20 s after the first run: merged.
        _seg(t0.add(const Duration(seconds: 40)), 30),
        // Two minutes later: a new passage.
        _seg(t0.add(const Duration(minutes: 3)), 40),
      ];
      final passages = findPassages('cam_a', segments, 20);
      expect(passages, hasLength(2));
      expect(passages.first.start, t0);
      expect(passages.first.end, t0.add(const Duration(seconds: 50)));
      expect(passages.first.peak, 80);
      expect(passages.last.camera, 'cam_a');

      final long = findPassages(
        'cam_a',
        segments,
        20,
        const PassageSettings(minDuration: Duration(seconds: 30)),
      );
      expect(long, hasLength(1));
    });

    test('coverage splits on holes in the recording', () {
      final t0 = _now;
      final coverage = recordingCoverage([
        _seg(t0, 0),
        _seg(t0.add(const Duration(seconds: 11)), 0),
        _seg(t0.add(const Duration(minutes: 5)), 0),
      ]);
      expect(coverage, hasLength(2));
      expect(coverage.first.end, t0.add(const Duration(seconds: 21)));
    });
  });

  group('TimelineData', () {
    final hourAgo = _now.subtract(const Duration(hours: 1));

    test('fetches the visible hours once, the focus camera first', () async {
      final server = _FakeRecordings({
        'cam_a': _recording(hourAgo, _now),
        'cam_b': _recording(hourAgo, _now),
      });
      var now = _now;
      final data = TimelineData(
        cameras: ['cam_a', 'cam_b'],
        fetch: server.fetch,
        clock: () => now,
      );
      data.ensure(hourAgo, _now, focus: 'cam_b');
      expect(data.loading, isTrue);
      await pumpEventQueue();
      expect(server.calls.first.$1, 'cam_b');
      expect(server.calls, hasLength(2));
      expect(data.segments('cam_a'), hasLength(360));
      expect(data.isLoaded('cam_a', hourAgo), isTrue);
      expect(data.loading, isFalse);

      data.ensure(hourAgo, _now, focus: 'cam_a');
      await pumpEventQueue();
      expect(server.calls, hasLength(2));
      data.dispose();
    });

    test('an hour still being recorded is fetched again later', () async {
      final server = _FakeRecordings({'cam_a': _recording(_now, _now)});
      var now = _now.add(const Duration(minutes: 20));
      final data = TimelineData(
        cameras: ['cam_a'],
        fetch: server.fetch,
        clock: () => now,
      );
      data.ensure(_now, now, focus: 'cam_a');
      await pumpEventQueue();
      expect(server.calls, hasLength(1));
      data.ensure(_now, now, focus: 'cam_a');
      await pumpEventQueue();
      expect(server.calls, hasLength(1));
      now = now.add(TimelineDefaults.liveRefresh);
      data.ensure(_now, now, focus: 'cam_a');
      await pumpEventQueue();
      expect(server.calls, hasLength(2));
      data.dispose();
    });

    test('a wide window only fills the focus camera', () async {
      final server = _FakeRecordings({});
      final cameras = [for (var i = 0; i < 6; i++) 'cam_$i'];
      final data = TimelineData(
        cameras: cameras,
        fetch: server.fetch,
        clock: () => _now,
      );
      data.ensure(
        _now.subtract(const Duration(hours: 24)),
        _now,
        focus: 'cam_3',
      );
      await pumpEventQueue();
      expect(server.calls.map((c) => c.$1).toSet(), {'cam_3'});
      expect(server.calls, hasLength(24));
      data.dispose();
    });

    test('previous and next find passages of any camera', () async {
      final quietFrom = _now.subtract(const Duration(hours: 5));
      final early = _now.subtract(const Duration(hours: 4, minutes: 30));
      final late = _now.subtract(const Duration(minutes: 10));
      final server = _FakeRecordings({
        'cam_a': _recording(quietFrom, _now, spikes: {early: 90}),
        'cam_b': _recording(quietFrom, _now, spikes: {late: 90}),
      });
      final data = TimelineData(
        cameras: ['cam_a', 'cam_b'],
        fetch: server.fetch,
        clock: () => _now,
      );
      final from = _now.subtract(const Duration(hours: 2));

      final next = await data.seekPassage(from, forward: true);
      expect(next?.camera, 'cam_b');
      expect(next?.start, late);

      final previous = await data.seekPassage(from, forward: false);
      expect(previous?.camera, 'cam_a');
      expect(previous?.start, early);

      // Nothing after the last passage up to now.
      expect(await data.seekPassage(late, forward: true), isNull);
      data.dispose();
    });

    test('an expired session is reported', () async {
      final server = _FakeRecordings({})..expired = true;
      var expired = 0;
      final data = TimelineData(
        cameras: ['cam_a'],
        fetch: server.fetch,
        clock: () => _now,
        onAuthError: () => expired++,
      );
      data.ensure(
        _now.subtract(const Duration(hours: 1)),
        _now,
        focus: 'cam_a',
      );
      await pumpEventQueue();
      expect(expired, 1);
      data.dispose();
    });

    test('historySpan covers the longest retention', () {
      expect(historySpan([0, 0.5]), const Duration(days: 1));
      expect(historySpan([3, 10, 0]), const Duration(days: 10));
    });
  });

  group('TimelineScreen', () {
    late _FakeRecordings server;
    late TimelineData data;
    late _FakePlayer player;
    final passageAt = _now.subtract(const Duration(minutes: 30));

    setUp(() {
      final from = _now.subtract(const Duration(hours: 4));
      server = _FakeRecordings({
        'cam_a': _recording(from, _now, base: 1),
        'cam_b': _recording(from, _now, spikes: {passageAt: 80}),
      });
      data = TimelineData(
        cameras: ['cam_a', 'cam_b'],
        fetch: server.fetch,
        clock: () => _now,
      );
      player = _FakePlayer();
    });

    tearDown(() => data.dispose());

    Future<void> pumpScreen(WidgetTester tester) async {
      // Phone-sized screen, so every control is laid out.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          TimelineScreen(
            cameras: [_camera('cam_a', 'Entrée'), _camera('cam_b', 'Cour')],
            data: data,
            playerFactory: () => player,
            clock: () => _now,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('opens the first camera just behind now', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Lecture · Entrée'), findsOneWidget);
      expect(find.text('Toutes les caméras'), findsNothing); // painted
      expect(find.byKey(const ValueKey('player')), findsOneWidget);
      final (camera, start, end) = player.opened.single;
      expect(camera, 'cam_a');
      expect(start, _now.subtract(TimelineScreenDefaults.startBehindNow));
      expect(end, _now);
      expect(server.calls, isNotEmpty);
      expect(find.text('6 h'), findsOneWidget);
      expect(find.text('Tout'), findsOneWidget);
    });

    testWidgets('previous passage switches to its camera and plays', (
      tester,
    ) async {
      await pumpScreen(tester);
      // Inside the range opened: a seek, not a new opening.
      await tester.tap(find.byTooltip('Avancer de 10 s'));
      await tester.pump();
      expect(player.seeks, [
        _now.subtract(const Duration(seconds: 50)),
      ]);
      expect(player.opened, hasLength(1));

      await tester.tap(find.text('Passage préc.'));
      await tester.pumpAndSettle();
      final (camera, start, _) = player.opened.last;
      expect(camera, 'cam_b');
      expect(start, passageAt);
      expect(player.playing, isTrue);
      expect(find.text('Lecture · Cour'), findsOneWidget);
    });

    testWidgets('no passage shows a message', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Passage suiv.'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun passage de mouvement dans les 24 h'),
        findsOneWidget,
      );
    });

    testWidgets('play, pause and camera menu', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Lecture'));
      await tester.pump();
      expect(player.playing, isTrue);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(player.playing, isFalse);

      await tester.tap(find.text('Lecture · Entrée'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cour').last);
      await tester.pumpAndSettle();
      expect(player.opened.last.$1, 'cam_b');

      await tester.tap(find.text('1 h'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1 h'))
            .selected,
        isTrue,
      );
    });

    testWidgets('releases the player when closed', (tester) async {
      await pumpScreen(tester);
      await tester.pumpWidget(_app(const SizedBox()));
      expect(player.disposed, isTrue);
    });
  });
}
