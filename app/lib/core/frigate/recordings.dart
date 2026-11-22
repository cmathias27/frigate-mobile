/// Recording segments of a camera, as returned by
/// `GET /api/<camera>/recordings?after=…&before=…`.
///
/// Frigate writes one segment about every 10 s, with the amount of motion
/// seen during it. The timeline builds its bands and the motion passages
/// from these segments, so it works on a server without object detection.
library;

/// One recorded segment of a camera.
class RecordingSegment {
  final DateTime start;
  final DateTime end;

  /// Motion score computed by Frigate for the segment (0 when still).
  final int motion;

  const RecordingSegment({
    required this.start,
    required this.end,
    required this.motion,
  });

  Duration get duration => end.difference(start);

  /// Reads one item of Frigate's answer; `null` when it is unusable.
  static RecordingSegment? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['start_time'];
    final end = json['end_time'];
    if (start is! num || end is! num || end < start) return null;
    final motion = json['motion'];
    return RecordingSegment(
      start: fromEpochSeconds(start),
      end: fromEpochSeconds(end),
      motion: motion is num ? motion.round() : 0,
    );
  }
}

/// Parses Frigate's list of segments, sorted by start time.
List<RecordingSegment> parseRecordings(Object? json) {
  if (json is! List) return const [];
  final segments = [
    for (final item in json) ?RecordingSegment.fromJson(item),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return segments;
}

/// Frigate's timestamps are Unix seconds, possibly with decimals.
DateTime fromEpochSeconds(num seconds) =>
    DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());

/// Unix seconds as Frigate expects them in query strings and VOD paths.
String epochSeconds(DateTime time) =>
    (time.millisecondsSinceEpoch / 1000).toStringAsFixed(0);
