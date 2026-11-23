import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';
import 'package:frigate_mobile/core/frigate/reviews.dart';
import 'package:frigate_mobile/features/events/alerts_screen.dart';
import 'package:frigate_mobile/features/events/review_list.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';

final _now = DateTime(2026, 1, 10, 15);

ReviewItem _item(
  String id, {
  String camera = 'cam_a',
  required int minutesAgo,
  ReviewSeverity severity = ReviewSeverity.alert,
  bool reviewed = false,
  List<String> objects = const ['person'],
  List<String> zones = const [],
}) {
  final start = _now.subtract(Duration(minutes: minutesAgo));
  return ReviewItem(
    id: id,
    camera: camera,
    start: start,
    end: start.add(const Duration(seconds: 42)),
    severity: severity,
    reviewed: reviewed,
    objects: objects,
    zones: zones,
    thumbnail: '/clips/review/thumb-$camera-$id.webp',
  );
}

/// Frigate answering `/api/review` from [items], recording every call.
class _Frigate {
  List<ReviewItem> items;
  final asked = <(DateTime, DateTime)>[];
  final marked = <(String, bool)>[];
  bool failing = false;
  bool refuseMark = false;

  /// When set, the next fetch waits for it before answering.
  Completer<void>? hold;

  _Frigate(this.items);

  Future<List<ReviewItem>> fetch({
    required DateTime after,
    required DateTime before,
    ReviewSeverity? severity,
    List<String>? cameras,
    int? limit,
  }) async {
    asked.add((after, before));
    final wait = hold;
    hold = null;
    if (wait != null) await wait.future;
    if (failing) throw Exception('offline');
    return [
      for (final i in items)
        if (!i.start.isBefore(after) && i.start.isBefore(before)) i,
    ];
  }

  Future<void> mark(List<String> ids, {bool reviewed = true}) async {
    marked.add((ids.join(','), reviewed));
    if (refuseMark) throw Exception('403');
  }
}

ReviewList _list(_Frigate frigate, {List<String>? cameras}) => ReviewList(
  fetch: frigate.fetch,
  mark: frigate.mark,
  cameras: cameras ?? const ['cam_a', 'cam_b'],
  history: const Duration(days: 3),
  clock: () => _now,
);

CameraCapabilities _camera(String name, String label) => CameraCapabilities(
  name: name,
  label: label,
  objectDetection: true,
  trackedObjects: const ['person', 'car'],
  recording: true,
  continuousDays: 1,
  motionDays: 0,
  alertDays: 3,
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
  group('parseReviews', () {
    test('reads alerts and detections, skips malformed entries', () {
      final items = parseReviews([
        {
          'id': '1767000000.1-abc',
          'camera': 'cam_door',
          'start_time': 1767000000.5,
          'end_time': 1767000042.5,
          'severity': 'alert',
          'has_been_reviewed': 1,
          'thumb_path': '/media/frigate/clips/review/thumb-cam_door-1.webp',
          'data': {
            'objects': ['person', 'person', 'car'],
            'audio': ['bark'],
            'sub_labels': ['Alice'],
            'zones': ['allee'],
          },
        },
        {
          'id': 'b',
          'camera': 'cam_b',
          'start_time': 1767000100,
          'end_time': null,
          'severity': 'detection',
          'has_been_reviewed': false,
        },
        {'id': 'c', 'camera': 'cam_b', 'severity': 'alert'},
        {'id': 'd', 'camera': 'cam_b', 'start_time': 1, 'severity': 'odd'},
        'noise',
      ]);
      expect(items, hasLength(2));
      final a = items.first;
      expect(a.reviewed, isTrue);
      expect(a.objects, ['person', 'car']);
      expect(a.labels, ['person', 'car', 'bark']);
      expect(a.subLabels, ['Alice']);
      expect(a.zones, ['allee']);
      expect(a.duration, const Duration(seconds: 42));
      expect(a.thumbnail, '/clips/review/thumb-cam_door-1.webp');
      final b = items.last;
      expect(b.severity, ReviewSeverity.detection);
      expect(b.reviewed, isFalse);
      expect(b.end, isNull);
      expect(b.duration, isNull);
      expect(b.thumbnail, isNull);
      expect(() => parseReviews({'x': 1}), throwsFormatException);
    });

    test('thumbnail paths stay on the served clips', () {
      expect(thumbnailPath('/clips/review/t.webp'), '/clips/review/t.webp');
      expect(thumbnailPath('/etc/passwd'), isNull);
      expect(thumbnailPath(''), isNull);
      expect(thumbnailPath(3), isNull);
    });
  });

  group('ReviewList', () {
    test('reads a day at a time back to the history start', () async {
      final frigate = _Frigate([
        _item('a', minutesAgo: 10),
        _item('b', minutesAgo: 30, severity: ReviewSeverity.detection),
        _item('c', minutesAgo: 60 * 30),
        _item('x', camera: 'cam_other', minutesAgo: 5),
      ]);
      final list = _list(frigate);
      await list.open();
      expect(list.items(ReviewSeverity.alert).map((i) => i.id), ['a']);
      expect(list.items(ReviewSeverity.detection).map((i) => i.id), ['b']);
      expect(list.unseen(), 2);
      expect(list.unseen(ReviewSeverity.alert), 1);
      await list.open();
      expect(frigate.asked, hasLength(1));

      await list.loadMore();
      expect(list.items(ReviewSeverity.alert).map((i) => i.id), ['a', 'c']);
      await list.loadMore();
      expect(list.reachedEnd, isTrue);
      await list.loadMore();
      expect(frigate.asked, hasLength(3));

      list.camera = 'cam_b';
      expect(list.items(ReviewSeverity.alert), isEmpty);
      expect(list.unseen(), 0);
      list.dispose();
    });

    test('marks seen at once, undone when Frigate refuses', () async {
      final frigate = _Frigate([
        _item('a', minutesAgo: 10),
        _item('b', minutesAgo: 20),
        _item('c', minutesAgo: 30, reviewed: true),
      ]);
      final list = _list(frigate);
      await list.open();

      expect(await list.markAllSeen(ReviewSeverity.alert), isTrue);
      expect(frigate.marked.single, ('a,b', true));
      expect(list.unseen(), 0);

      frigate.refuseMark = true;
      final c = list.items(ReviewSeverity.alert).last;
      expect(await list.mark([c], reviewed: false), isFalse);
      expect(list.items(ReviewSeverity.alert).last.reviewed, isTrue);

      // Nothing to change: Frigate is not asked.
      expect(await list.mark([c]), isTrue);
      expect(frigate.marked, hasLength(2));
      list.dispose();
    });

    test('a page still on its way is dropped by a refresh', () async {
      final frigate = _Frigate([
        _item('a', minutesAgo: 10),
        _item('old', minutesAgo: 60 * 30),
      ]);
      final list = _list(frigate);
      await list.open();
      final late = Completer<void>();
      frigate.hold = late;
      final more = list.loadMore();
      expect(list.loading, isTrue);

      // The alert is gone from Frigate; the refresh answers first.
      frigate.items = [_item('a', minutesAgo: 10)];
      await list.refresh();
      expect(list.loading, isFalse);
      late.complete();
      await more;

      // The older day, asked before the refresh, is not mixed in.
      expect(list.items(ReviewSeverity.alert).map((i) => i.id), ['a']);
      expect(list.loading, isFalse);
      expect(list.reachedEnd, isFalse);
      expect(list.from, _now.subtract(ReviewListDefaults.page));
      list.dispose();
    });

    test('a failure can be retried', () async {
      final frigate = _Frigate([_item('a', minutesAgo: 10)])..failing = true;
      final list = _list(frigate);
      await list.open();
      expect(list.failed, isTrue);
      expect(list.from, isNull);
      frigate.failing = false;
      await list.retry();
      expect(list.failed, isFalse);
      expect(list.items(ReviewSeverity.alert), hasLength(1));
      list.dispose();
    });
  });

  group('AlertsScreen', () {
    late _Frigate frigate;
    late ReviewList list;
    late List<ReviewItem> opened;
    final thumbs = ReviewThumbnails((_) async => Uint8List(0));

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          AlertsScreen(
            reviews: list,
            thumbnails: thumbs,
            cameras: [_camera('cam_a', 'Entrée'), _camera('cam_b', 'Cour')],
            motion: (_) => const Text('passages'),
            onOpen: opened.add,
            clock: () => _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      frigate = _Frigate([
        _item('a', minutesAgo: 10, zones: ['allee']),
        _item('b', camera: 'cam_b', minutesAgo: 20, objects: ['car']),
        _item('c', minutesAgo: 30, reviewed: true),
        _item(
          'd',
          minutesAgo: 40,
          severity: ReviewSeverity.detection,
          objects: ['dog'],
        ),
      ]);
      list = _list(frigate);
      opened = [];
    });

    tearDown(() => list.dispose());

    testWidgets('lists alerts, unseen count, and opens one as seen', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Personne · Entrée'), findsNWidgets(2));
      expect(find.text('Voiture · Cour'), findsOneWidget);
      expect(find.textContaining('allee'), findsOneWidget);
      expect(find.text('2 non vues'), findsOneWidget);
      expect(find.text('Chien · Entrée'), findsNothing);

      await tester.tap(find.text('Voiture · Cour'));
      await tester.pumpAndSettle();
      expect(opened.single.id, 'b');
      expect(frigate.marked.single, ('b', true));
      expect(find.text('1 non vue'), findsOneWidget);
    });

    testWidgets('detections, motion, camera filter', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Détections'));
      await tester.pumpAndSettle();
      expect(find.text('Chien · Entrée'), findsOneWidget);
      expect(find.text('Voiture · Cour'), findsNothing);

      await tester.tap(find.text('Alertes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cour'));
      await tester.pumpAndSettle();
      expect(find.text('Personne · Entrée'), findsNothing);
      expect(find.text('Voiture · Cour'), findsOneWidget);

      await tester.tap(find.text('Mouvement'));
      await tester.pumpAndSettle();
      expect(find.text('passages'), findsOneWidget);
    });

    testWidgets('swipe, multi-select and mark all seen', (tester) async {
      await pump(tester);
      await tester.drag(find.text('Voiture · Cour'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(frigate.marked.last, ('b', true));
      expect(find.text('Voiture · Cour'), findsOneWidget);

      // Long press selects; a touch then adds to the selection.
      final rows = find.text('Personne · Entrée');
      await tester.longPress(rows.first);
      await tester.pumpAndSettle();
      await tester.tap(rows.last);
      await tester.pumpAndSettle();
      expect(find.text('2 sélectionnées'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.tap(find.text('Marquer vu'));
      await tester.pumpAndSettle();
      expect(frigate.marked.last, ('a', true));
      expect(find.text('Tout marquer vu'), findsNothing);
    });

    testWidgets('a refused mark is undone and said', (tester) async {
      frigate.refuseMark = true;
      await pump(tester);
      await tester.tap(find.text('Tout marquer vu'));
      await tester.pumpAndSettle();
      expect(find.text('2 non vues'), findsOneWidget);
      expect(
        find.text("Frigate n'a pas enregistré la marque «\u00a0vu\u00a0»."),
        findsOneWidget,
      );
    });
  });
}
