import '../../core/frigate/client.dart';
import '../../core/frigate/recordings.dart';
import 'timeline_data.dart';

typedef RecordingHoursFetcher = Future<List<RecordingHour>> Function(
  String camera,
);

/// How a day of the calendar was recorded.
enum DayRecording {
  /// Some recordings only: alerts, motion, or a gap in the day.
  partial,

  /// Recorded most of the time it could be, by at least one camera.
  full,
}

abstract final class HistoryDefaults {
  /// Share of a day recorded by one camera above which the day is full.
  static const fullShare = 0.8;
}

/// Every day recorded by the cameras, for the calendar of the timeline
/// (mock-up screen 4b). Nothing is fixed: the history goes back as far as
/// the retention set in Frigate keeps recordings.
class RecordingHistory {
  /// Local days (midnight) with recordings.
  final Map<DateTime, DayRecording> days;

  /// Start of the oldest recording kept, when known.
  final DateTime? oldest;

  const RecordingHistory({required this.days, this.oldest});

  static const empty = RecordingHistory(days: {});

  DayRecording? at(DateTime day) => days[dayOf(day)];

  DateTime? get newestDay =>
      days.isEmpty ? null : days.keys.reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Local midnight of [time].
DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// Builds the days from the hours of every camera.
///
/// A day is full when one camera recorded at least [fullShare] of the part
/// of the day that could be recorded: from the oldest recording kept, up
/// to [now].
RecordingHistory buildHistory(
  Map<String, List<RecordingHour>> hoursByCamera, {
  required DateTime now,
  DateTime? oldest,
  double fullShare = HistoryDefaults.fullShare,
}) {
  final first =
      oldest ??
      hoursByCamera.values
          .expand((hours) => hours)
          .where((h) => h.recorded > Duration.zero)
          .fold<DateTime?>(
            null,
            (min, h) => min == null || h.start.isBefore(min) ? h.start : min,
          );
  // Recorded time per day, per camera.
  final perDay = <DateTime, Map<String, Duration>>{};
  hoursByCamera.forEach((camera, hours) {
    for (final hour in hours) {
      if (hour.recorded <= Duration.zero) continue;
      final cameras = perDay.putIfAbsent(dayOf(hour.start), () => {});
      cameras[camera] = (cameras[camera] ?? Duration.zero) + hour.recorded;
    }
  });
  final days = <DateTime, DayRecording>{};
  perDay.forEach((day, cameras) {
    final next = DateTime(day.year, day.month, day.day + 1);
    var from = day;
    if (first != null && first.isAfter(from)) from = first;
    final to = now.isBefore(next) ? now : next;
    final possible = to.difference(from);
    final best = cameras.values.reduce((a, b) => a > b ? a : b);
    days[day] =
        possible > Duration.zero &&
            best.inSeconds >= possible.inSeconds * fullShare
        ? DayRecording.full
        : DayRecording.partial;
  });
  return RecordingHistory(days: days, oldest: first);
}

/// Reads the history of [cameras]: their hours, then the first segment of
/// the oldest hour for the exact start.
///
/// A camera that cannot be read is left out; an expired session is
/// rethrown.
Future<RecordingHistory> loadRecordingHistory({
  required List<String> cameras,
  required RecordingHoursFetcher fetchHours,
  required RecordingsFetcher fetchSegments,
  DateTime Function()? clock,
  double fullShare = HistoryDefaults.fullShare,
}) async {
  final results = await Future.wait([
    for (final camera in cameras)
      fetchHours(camera).then<List<RecordingHour>?>(
        (hours) => hours,
        onError: (Object error) {
          if (error is FrigateAuthException) throw error;
          return null;
        },
      ),
  ]);
  final byCamera = <String, List<RecordingHour>>{
    for (var i = 0; i < cameras.length; i++)
      if (results[i] != null) cameras[i]: results[i]!,
  };
  if (byCamera.values.every((hours) => hours.isEmpty)) {
    return RecordingHistory.empty;
  }

  // Oldest hour of all, then its first segment for the exact start.
  String? oldestCamera;
  RecordingHour? oldestHour;
  byCamera.forEach((camera, hours) {
    for (final hour in hours) {
      if (hour.recorded <= Duration.zero) continue;
      if (oldestHour == null || hour.start.isBefore(oldestHour!.start)) {
        oldestHour = hour;
        oldestCamera = camera;
      }
      break; // Hours are sorted.
    }
  });
  DateTime? oldest = oldestHour?.start;
  if (oldestHour != null) {
    try {
      final segments = await fetchSegments(
        oldestCamera!,
        oldestHour!.start,
        oldestHour!.start.add(const Duration(hours: 1)),
      );
      if (segments.isNotEmpty) oldest = segments.first.start;
    } on FrigateAuthException {
      rethrow;
    } catch (_) {
      // The hour is precise enough.
    }
  }
  return buildHistory(
    byCamera,
    now: (clock ?? DateTime.now)(),
    oldest: oldest,
    fullShare: fullShare,
  );
}
