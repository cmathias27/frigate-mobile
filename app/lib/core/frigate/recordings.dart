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

/// One hour of recordings of a camera, from
/// `GET /api/<camera>/recordings/summary?timezone=utc`.
class RecordingHour {
  /// Start of the hour, in local time.
  final DateTime start;

  /// Recorded time during the hour.
  final Duration recorded;

  /// Sum of the motion scores of the hour.
  final int motion;

  const RecordingHour({
    required this.start,
    required this.recorded,
    required this.motion,
  });
}

/// Parses the per-camera summary asked in UTC (`[{day, hours: [{hour,
/// duration, motion}]}]`), so hours land on the right local day whatever
/// the time zone of the phone; skips unusable items.
List<RecordingHour> parseRecordingHours(Object? json) {
  if (json is! List) return const [];
  final hours = <RecordingHour>[];
  for (final day in json) {
    if (day is! Map || day['day'] is! String || day['hours'] is! List) {
      continue;
    }
    final date = DateTime.tryParse('${day['day']}T00:00:00Z');
    if (date == null) continue;
    for (final hour in day['hours'] as List) {
      if (hour is! Map) continue;
      final h = int.tryParse('${hour['hour']}');
      final duration = hour['duration'];
      if (h == null || h < 0 || h > 23 || duration is! num) continue;
      final motion = hour['motion'];
      hours.add(
        RecordingHour(
          start: date.add(Duration(hours: h)).toLocal(),
          recorded: Duration(milliseconds: (duration * 1000).round()),
          motion: motion is num ? motion.round() : 0,
        ),
      );
    }
  }
  return hours..sort((a, b) => a.start.compareTo(b.start));
}
