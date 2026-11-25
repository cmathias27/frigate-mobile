import '../../core/frigate/reviews.dart';
import 'motion_passages.dart';
import 'timeline_data.dart';

/// Reads Frigate's review items overlapping a period (see
/// `FrigateClient.fetchReviews`).
typedef ReviewFetcher = Future<List<ReviewItem>> Function({
  required DateTime after,
  required DateTime before,
  ReviewSeverity? severity,
  List<String>? cameras,
  int? limit,
});

abstract final class ReviewSeekDefaults {
  /// Played before an alert or a detection, so its beginning is seen.
  static const preRoll = Duration(seconds: 2);
}

/// Finds Frigate's alerts and detections next to a time, for previous and
/// next in the timeline when they are chosen over motion.
class ReviewSeeker {
  final ReviewFetcher _fetch;

  /// Recorded cameras that produce alerts or detections.
  final List<String> cameras;
  final DateTime Function() _clock;

  ReviewSeeker(
    this._fetch, {
    required this.cameras,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The alert or detection next to [from], of [camera] only when given, of
  /// any camera otherwise, within [TimelineDefaults.seekLimit]: the first
  /// one starting after it, or the last one starting before it. Returned as
  /// a passage starting [ReviewSeekDefaults.preRoll] early.
  Future<MotionPassage?> seek(
    DateTime from, {
    required bool forward,
    String? camera,
  }) async {
    final searched = camera == null
        ? cameras
        : [if (cameras.contains(camera)) camera];
    if (searched.isEmpty) return null;
    const limit = TimelineDefaults.seekLimit;
    const preRoll = ReviewSeekDefaults.preRoll;
    final now = _clock();
    final after = forward ? from : from.subtract(limit);
    var before = forward ? from.add(limit) : from;
    if (before.isAfter(now)) before = now;
    if (!before.isAfter(after)) return null;

    final items = await _fetch(after: after, before: before, cameras: searched);
    // Same margins as motion passages: a second press goes past the item
    // being played.
    final afterFrom = from.add(const Duration(seconds: 1));
    final beforeFrom = from.subtract(const Duration(seconds: 2));
    ReviewItem? best;
    for (final item in items) {
      if (!searched.contains(item.camera)) continue;
      final start = item.start.subtract(preRoll);
      if (forward) {
        if (start.isAfter(afterFrom) &&
            (best == null || item.start.isBefore(best.start))) {
          best = item;
        }
      } else if (start.isBefore(beforeFrom) &&
          !item.start.isBefore(after) &&
          (best == null || item.start.isAfter(best.start))) {
        best = item;
      }
    }
    if (best == null) return null;
    final end = best.end ?? now;
    return MotionPassage(
      camera: best.camera,
      start: best.start.subtract(preRoll),
      end: end.isAfter(best.start) ? end : best.start,
      peak: 0,
    );
  }
}
