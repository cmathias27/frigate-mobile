import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/theme.dart';
import '../../core/frigate/recordings.dart';
import 'motion_passages.dart';
import 'timeline_data.dart';

/// The two bands of the timeline under a fixed playhead: every camera
/// merged on top, the camera being played below, taller and detailed.
///
/// Dragging moves time under the playhead; tapping the top band jumps to the
/// nearest passage of any camera, tapping the lower band to that time.
class TimelineBands extends StatelessWidget {
  final TimelineData data;
  final String camera;
  final Map<String, String> labels;
  final String allLabel;
  final DateTime playhead;
  final Duration span;
  final DateTime now;
  final VoidCallback onScrubStart;

  /// Time moved under the playhead since the last call.
  final ValueChanged<Duration> onScrub;
  final VoidCallback onScrubEnd;
  final ValueChanged<MotionPassage> onPassage;
  final ValueChanged<DateTime> onTime;

  const TimelineBands({
    super.key,
    required this.data,
    required this.camera,
    required this.labels,
    required this.allLabel,
    required this.playhead,
    required this.span,
    required this.now,
    required this.onScrubStart,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onPassage,
    required this.onTime,
  });

  static const allHeight = 34.0;
  static const cameraHeight = 54.0;
  static const ticksHeight = 18.0;
  static const gap = 6.0;
  static const height = allHeight + gap + cameraHeight + ticksHeight;

  /// Taps within this distance of a passage select it.
  static const tapSlop = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.localeOf(context).toString();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final from = playhead.subtract(span ~/ 2);
        DateTime timeAt(double x) => from.add(span * (x / width));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => onScrubStart(),
          onHorizontalDragUpdate: (d) => onScrub(span * (-d.delta.dx / width)),
          onHorizontalDragEnd: (_) => onScrubEnd(),
          onTapUp: (d) {
            final y = d.localPosition.dy;
            final x = d.localPosition.dx;
            if (y <= allHeight) {
              final passage = _nearest(x, width, from);
              if (passage != null) return onPassage(passage);
            }
            if (y <= allHeight + gap + cameraHeight) onTime(timeAt(x));
          },
          // Full width: a Stack lays its children out loosely, and a band
          // without width is neither painted nor draggable.
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _BandsPainter(
                data: data,
                camera: camera,
                labels: labels,
                allLabel: allLabel,
                from: from,
                span: span,
                now: now,
                locale: l10n,
              ),
            ),
          ),
        );
      },
    );
  }

  MotionPassage? _nearest(double x, double width, DateTime from) {
    MotionPassage? best;
    var bestDistance = tapSlop;
    for (final p in data.allPassages()) {
      final a = _x(p.start, from, width);
      final b = max(_x(p.end, from, width), a + 3);
      final distance = x < a ? a - x : (x > b ? x - b : 0.0);
      if (distance <= bestDistance) {
        best = p;
        bestDistance = distance;
      }
    }
    return best;
  }

  double _x(DateTime t, DateTime from, double width) =>
      t.difference(from).inMilliseconds / span.inMilliseconds * width;
}

class _BandsPainter extends CustomPainter {
  final TimelineData data;
  final String camera;
  final Map<String, String> labels;
  final String allLabel;
  final DateTime from;
  final Duration span;
  final DateTime now;
  final String locale;

  _BandsPainter({
    required this.data,
    required this.camera,
    required this.labels,
    required this.allLabel,
    required this.from,
    required this.span,
    required this.now,
    required this.locale,
  });

  late double _width;

  double _x(DateTime t) =>
      t.difference(from).inMilliseconds / span.inMilliseconds * _width;

  @override
  void paint(Canvas canvas, Size size) {
    _width = size.width;
    const allTop = 0.0;
    const cameraTop = TimelineBands.allHeight + TimelineBands.gap;
    _band(canvas, allTop, TimelineBands.allHeight, all: true);
    _band(canvas, cameraTop, TimelineBands.cameraHeight, all: false);
    _ticks(canvas, cameraTop + TimelineBands.cameraHeight, size);
  }

  void _band(Canvas canvas, double top, double height, {required bool all}) {
    final rect = Rect.fromLTWH(0, top, _width, height);
    final clip = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(rect, Paint()..color = AppColors.surface);

    final recorded = Paint()..color = AppColors.recording;
    for (final c in all ? data.cameras : [camera]) {
      for (final span in data.coverage(c)) {
        _fill(canvas, span.start, span.end, top, height, recorded);
      }
    }

    if (!all) _motion(canvas, top, height);

    final passages = all ? data.allPassages() : data.passages(camera);
    final fill = Paint()
      ..color = AppColors.passage.withValues(alpha: all ? 0.75 : 0.28);
    final edge = Paint()..color = AppColors.passage;
    for (final p in passages) {
      final a = _x(p.start);
      final b = max(_x(p.end), a + 2);
      if (b < 0 || a > _width) continue;
      canvas.drawRect(Rect.fromLTRB(a, top, b, top + height), fill);
      if (!all) canvas.drawRect(Rect.fromLTRB(a, top, b, top + 3), edge);
      if (all) _label(canvas, p, a, b, top, height);
    }

    // Time to come.
    final future = _x(now);
    if (future < _width) {
      canvas.drawRect(
        Rect.fromLTRB(max(future, 0), top, _width, top + height),
        Paint()..color = AppColors.background.withValues(alpha: 0.7),
      );
    }

    final name = all ? allLabel : labels[camera];
    if (name != null) _bandName(canvas, name, top);
    canvas.restore();
  }

  void _fill(
    Canvas canvas,
    DateTime start,
    DateTime end,
    double top,
    double height,
    Paint paint,
  ) {
    final a = _x(start);
    final b = _x(end);
    if (b < 0 || a > _width) return;
    canvas.drawRect(Rect.fromLTRB(a, top, max(b, a + 1), top + height), paint);
  }

  /// Grey bars of motion, highest score per 2 px, scaled on the threshold.
  void _motion(Canvas canvas, double top, double height) {
    final segments = data.segments(camera);
    if (segments.isEmpty) return;
    final threshold = max(data.threshold(camera), 1);
    const step = 2.0;
    final buckets = List<int>.filled((_width / step).ceil() + 1, 0);
    final end = from.add(span);
    for (final s in _visible(segments, end)) {
      final a = max(_x(s.start), 0.0) ~/ step;
      final b = min(_x(s.end), _width) ~/ step;
      for (var i = a; i <= b && i < buckets.length; i++) {
        if (s.motion > buckets[i]) buckets[i] = s.motion;
      }
    }
    final paint = Paint()..color = AppColors.motion;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i] == 0) continue;
      final level = min(buckets[i] / (threshold * 2), 1.0);
      final h = max(level * (height - 8), 1.5);
      canvas.drawRect(
        Rect.fromLTWH(i * step, top + height - h, step - 0.5, h),
        paint,
      );
    }
  }

  Iterable<RecordingSegment> _visible(
    List<RecordingSegment> segments,
    DateTime end,
  ) sync* {
    // First segment ending after the window start.
    var lo = 0;
    var hi = segments.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (segments[mid].end.isBefore(from)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    for (var i = lo; i < segments.length; i++) {
      if (segments[i].start.isAfter(end)) break;
      yield segments[i];
    }
  }

  void _label(
    Canvas canvas,
    MotionPassage p,
    double a,
    double b,
    double top,
    double height,
  ) {
    final name = labels[p.camera] ?? p.camera;
    final short = name.length > 3 ? name.substring(0, 2) : name;
    final painter = _text(short, 10, Colors.black);
    if (b - a < painter.width + 4) return;
    painter.paint(
      canvas,
      Offset(a + 2, top + height - painter.height - 2),
    );
  }

  void _bandName(Canvas canvas, String name, double top) {
    _text(name, 10, AppColors.textDim).paint(canvas, Offset(6, top + 4));
  }

  void _ticks(Canvas canvas, double top, Size size) {
    final step = _tickStep(span);
    final format = step >= const Duration(days: 1)
        ? DateFormat.MEd(locale)
        : (step >= const Duration(hours: 1)
              ? DateFormat.H(locale)
              : DateFormat.Hm(locale));
    final end = from.add(span);
    var t = alignTick(from, step);
    final line = Paint()
      ..color = AppColors.textDim.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    while (!t.isAfter(end)) {
      final x = _x(t);
      canvas.drawLine(Offset(x, top), Offset(x, top + 4), line);
      final painter = _text(format.format(t), 10, AppColors.textDim);
      painter.paint(canvas, Offset(x - painter.width / 2, top + 5));
      t = nextTick(t, step);
    }
  }

  static Duration _tickStep(Duration span) {
    if (span <= const Duration(hours: 1)) return const Duration(minutes: 10);
    if (span <= const Duration(hours: 6)) return const Duration(hours: 1);
    if (span <= const Duration(hours: 24)) return const Duration(hours: 4);
    return const Duration(days: 1);
  }

  TextPainter _text(String text, double size, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_BandsPainter old) => true;
}

/// First tick at or after [t]: a local time whose clock reading is a
/// multiple of [step] (midnight for days), whatever the summer time.
DateTime alignTick(DateTime t, Duration step) {
  if (step >= const Duration(days: 1)) {
    final day = DateTime(t.year, t.month, t.day);
    return day.isBefore(t) ? DateTime(t.year, t.month, t.day + 1) : day;
  }
  final minutes = step.inMinutes;
  // The clock reading, not the time elapsed since midnight: the two differ
  // by an hour on the days the clocks change.
  final reading = t.hour * 60 + t.minute;
  var aligned = DateTime(
    t.year,
    t.month,
    t.day,
    0,
    (reading ~/ minutes) * minutes,
  );
  // In the hour repeated in autumn, the reading may name the first pass.
  while (aligned.isBefore(t)) {
    aligned = nextTick(aligned, step);
  }
  return aligned;
}

/// The tick after [t]: same clock steps across a change of the clocks, a
/// day being from midnight to midnight.
DateTime nextTick(DateTime t, Duration step) {
  if (step >= const Duration(days: 1)) {
    return DateTime(t.year, t.month, t.day + step.inDays);
  }
  final next = DateTime(
    t.year,
    t.month,
    t.day,
    t.hour,
    t.minute + step.inMinutes,
  );
  // An hour skipped in spring gives a reading that does not exist: the
  // clock then jumps, never back to [t] or before.
  return next.isAfter(t) ? next : t.add(step);
}
