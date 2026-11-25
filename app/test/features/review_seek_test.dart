import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/reviews.dart';
import 'package:frigate_mobile/features/timeline/review_seek.dart';

final _now = DateTime(2026, 1, 10, 12);

ReviewItem _item(String id, String camera, DateTime start, {DateTime? end}) =>
    ReviewItem(
      id: id,
      camera: camera,
      start: start,
      end: end,
      severity: ReviewSeverity.alert,
      reviewed: false,
    );

/// Answers like Frigate: the items overlapping the period asked.
class _FakeReviews {
  final List<ReviewItem> items;
  final asked = <(DateTime, DateTime, List<String>?)>[];

  _FakeReviews(this.items);

  Future<List<ReviewItem>> fetch({
    required DateTime after,
    required DateTime before,
    ReviewSeverity? severity,
    List<String>? cameras,
    int? limit,
  }) async {
    asked.add((after, before, cameras));
    return [
      for (final i in items)
        if (i.start.isBefore(before) && (i.end ?? _now).isAfter(after)) i,
    ];
  }
}

void main() {
  final at = _now.subtract(const Duration(hours: 1));
  final a1 = _item(
    'a1',
    'cam_a',
    at.subtract(const Duration(minutes: 20)),
    end: at.subtract(const Duration(minutes: 19)),
  );
  final b1 = _item(
    'b1',
    'cam_b',
    at.subtract(const Duration(minutes: 5)),
    end: at.subtract(const Duration(minutes: 4)),
  );
  final a2 = _item(
    'a2',
    'cam_a',
    at.add(const Duration(minutes: 10)),
    end: at.add(const Duration(minutes: 11)),
  );
  final ongoing = _item(
    'b2',
    'cam_b',
    _now.subtract(const Duration(minutes: 1)),
  );

  ReviewSeeker seeker(_FakeReviews server, {List<String>? cameras}) =>
      ReviewSeeker(
        server.fetch,
        cameras: cameras ?? ['cam_a', 'cam_b'],
        clock: () => _now,
      );

  test('next and previous on every camera, starting a little early', () async {
    final server = _FakeReviews([a1, b1, a2, ongoing]);
    final next = await seeker(server).seek(at, forward: true);
    expect(next!.camera, 'cam_a');
    expect(next.start, a2.start.subtract(ReviewSeekDefaults.preRoll));
    expect(next.end, a2.end);

    final previous = await seeker(server).seek(at, forward: false);
    expect(previous!.camera, 'cam_b');
    expect(previous.start, b1.start.subtract(ReviewSeekDefaults.preRoll));

    // Never asks past now.
    final (_, before, _) = server.asked.first;
    expect(before, _now);
  });

  test('a second press goes past the item just opened', () async {
    final server = _FakeReviews([a1, b1, a2]);
    final s = seeker(server);
    final first = await s.seek(at, forward: false);
    final second = await s.seek(first!.start, forward: false);
    expect(second!.start, a1.start.subtract(ReviewSeekDefaults.preRoll));

    final forward = await s.seek(second.start, forward: true);
    expect(forward!.start, first.start);
  });

  test('only the camera asked, and only cameras with reviews', () async {
    final server = _FakeReviews([a1, b1, a2]);
    final previous = await seeker(server).seek(
      at,
      forward: false,
      camera: 'cam_a',
    );
    expect(previous!.camera, 'cam_a');
    expect(server.asked.last.$3, ['cam_a']);

    // A camera that produces no review is not asked for.
    final none = await seeker(
      server,
      cameras: ['cam_b'],
    ).seek(at, forward: false, camera: 'cam_a');
    expect(none, isNull);
    expect(server.asked, hasLength(1));
  });

  test('an item still going on ends now', () async {
    final server = _FakeReviews([ongoing]);
    final next = await seeker(server).seek(at, forward: true);
    expect(next!.end, _now);
  });

  test('nothing within the limit, nothing after now', () async {
    final server = _FakeReviews([a1]);
    expect(await seeker(server).seek(at, forward: true), isNull);
    expect(await seeker(server).seek(_now, forward: true), isNull);
    // Older than the limit: out of reach backwards.
    final old = _FakeReviews([
      _item(
        'old',
        'cam_a',
        at.subtract(const Duration(hours: 30)),
        end: at.subtract(const Duration(hours: 29, minutes: 59)),
      ),
    ]);
    expect(await seeker(old).seek(at, forward: false), isNull);
  });
}
