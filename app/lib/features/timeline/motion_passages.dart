import 'dart:math';

import '../../core/frigate/recordings.dart';

/// How motion passages are found in a camera's segments. Defaults suit the
/// cameras seen so far; per-camera settings come with the 0.2 settings
/// screen (decision 0002).
class PassageSettings {
  /// Lowest automatic threshold: below it, a still camera with sensor noise
  /// would turn every flicker into a passage.
  final int floor;

  /// Automatic threshold above the camera's usual motion, in interquartile
  /// ranges past the third quartile (Tukey's fence).
  final double spread;

  /// Two passages closer than this are one.
  final Duration mergeGap;

  /// Shorter passages are ignored.
  final Duration minDuration;

  /// Fixed threshold for the camera, instead of the automatic one.
  final int? threshold;

  const PassageSettings({
    this.floor = 10,
    this.spread = 1.5,
    this.mergeGap = const Duration(seconds: 30),
    this.minDuration = Duration.zero,
    this.threshold,
  });
}

/// A stretch of a camera's recording with more motion than usual.
class MotionPassage {
  final String camera;
  final DateTime start;
  final DateTime end;

  /// Highest motion score of the passage.
  final int peak;

  const MotionPassage({
    required this.camera,
    required this.start,
    required this.end,
    required this.peak,
  });

  Duration get duration => end.difference(start);

  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  @override
  String toString() => 'MotionPassage($camera, $start → $end, $peak)';
}

/// Motion score above which a segment belongs to a passage, from the
/// camera's own motion: a noisy garage gets a higher threshold than a quiet
/// hallway, without any setting.
int passageThreshold(
  Iterable<int> motions, [
  PassageSettings settings = const PassageSettings(),
]) {
  if (settings.threshold case final fixed?) return fixed;
  final sorted = motions.toList()..sort();
  if (sorted.isEmpty) return settings.floor;
  int quantile(double q) => sorted[((sorted.length - 1) * q).round()];
  final q1 = quantile(0.25);
  final q3 = quantile(0.75);
  final fence = (q3 + settings.spread * (q3 - q1)).ceil();
  return max(settings.floor, fence);
}

/// Passages of [camera] in its sorted [segments]: runs of segments above
/// [threshold], joined when less than [PassageSettings.mergeGap] apart.
List<MotionPassage> findPassages(
  String camera,
  List<RecordingSegment> segments,
  int threshold, [
  PassageSettings settings = const PassageSettings(),
]) {
  final passages = <MotionPassage>[];
  DateTime? start;
  DateTime? end;
  var peak = 0;

  void close() {
    if (start != null && end!.difference(start!) >= settings.minDuration) {
      passages.add(
        MotionPassage(camera: camera, start: start!, end: end, peak: peak),
      );
    }
    start = null;
  }

  for (final segment in segments) {
    if (segment.motion <= threshold) continue;
    if (start != null && segment.start.difference(end!) > settings.mergeGap) {
      close();
    }
    if (start == null) {
      start = segment.start;
      end = segment.end;
      peak = segment.motion;
    } else {
      if (segment.end.isAfter(end!)) end = segment.end;
      peak = max(peak, segment.motion);
    }
  }
  close();
  return passages;
}

/// A recorded stretch without interruption.
typedef Coverage = ({DateTime start, DateTime end});

/// Recorded stretches of sorted [segments]: a hole longer than [tolerance]
/// between two segments is a gap in the recording.
List<Coverage> recordingCoverage(
  List<RecordingSegment> segments, {
  Duration tolerance = const Duration(seconds: 5),
}) {
  final result = <Coverage>[];
  for (final segment in segments) {
    if (result.isNotEmpty &&
        segment.start.difference(result.last.end) <= tolerance) {
      if (segment.end.isAfter(result.last.end)) {
        result.last = (start: result.last.start, end: segment.end);
      }
    } else {
      result.add((start: segment.start, end: segment.end));
    }
  }
  return result;
}
