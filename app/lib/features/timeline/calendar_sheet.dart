import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, toBeginningOfSentenceCase;

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'recording_history.dart';

abstract final class CalendarDefaults {
  /// Times of the "this morning" and "last evening" shortcuts.
  static const morning = TimeOfDay(hour: 8, minute: 0);
  static const evening = TimeOfDay(hour: 20, minute: 0);
}

/// Opens the calendar of the whole history (mock-up screen 4b) and returns
/// the time chosen, or `null` when closed.
Future<DateTime?> showRecordingCalendar(
  BuildContext context, {
  required Future<RecordingHistory> Function() load,
  required DateTime selected,
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) =>
        RecordingCalendarSheet(load: load, selected: selected, clock: clock),
  );
}

class RecordingCalendarSheet extends StatefulWidget {
  final Future<RecordingHistory> Function() load;
  final DateTime selected;
  final DateTime Function()? clock;

  const RecordingCalendarSheet({
    super.key,
    required this.load,
    required this.selected,
    this.clock,
  });

  @override
  State<RecordingCalendarSheet> createState() => _RecordingCalendarSheetState();
}

class _RecordingCalendarSheetState extends State<RecordingCalendarSheet> {
  late Future<RecordingHistory> _history;
  late DateTime _month;
  late DateTime _day;
  late TimeOfDay _time;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _history = widget.load();
    _day = dayOf(widget.selected);
    _month = DateTime(_day.year, _day.month);
    _time = TimeOfDay.fromDateTime(widget.selected);
  }

  DateTime get _chosen {
    final time = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _time.hour,
      _time.minute,
    );
    final now = _now();
    return time.isAfter(now) ? now : time;
  }

  void _close(DateTime time) => Navigator.of(context).pop(time);

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null && mounted) setState(() => _time = time);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FutureBuilder<RecordingHistory>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.calendarLoadFailed),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _history = widget.load()),
                    child: Text(l.timelineRetry),
                  ),
                ],
              );
            }
            final history = snapshot.data;
            if (history == null) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _content(l, history);
          },
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l, RecordingHistory history) {
    final locale = Localizations.localeOf(context).toString();
    final text = Theme.of(context).textTheme;
    final now = _now();
    final firstMonth = _firstMonth(history, now);
    final lastMonth = DateTime(now.year, now.month);
    final oldest = history.oldest;

    final today = dayOf(now);
    final morning = _at(today, CalendarDefaults.morning);
    final evening = _at(
      DateTime(today.year, today.month, today.day - 1),
      CalendarDefaults.evening,
    );
    bool kept(DateTime time) =>
        !time.isAfter(now) && (oldest == null || !time.isBefore(oldest));
    final shortcuts = [
      (l.calendarHourAgo, now.subtract(const Duration(hours: 1))),
      (l.calendarThisMorning, morning),
      (l.calendarLastEvening, evening),
      if (oldest != null) (l.calendarOldest, oldest),
    ].where((s) => kept(s.$2));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l.calendarPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _month.isAfter(firstMonth)
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                toBeginningOfSentenceCase(
                  DateFormat.yMMMM(locale).format(_month),
                  locale,
                ),
                textAlign: TextAlign.center,
                style: text.titleLarge,
              ),
            ),
            IconButton(
              tooltip: l.calendarNextMonth,
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _month.isBefore(lastMonth)
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    )
                  : null,
            ),
          ],
        ),
        _MonthGrid(
          month: _month,
          history: history,
          selected: _day,
          onDay: (day) => setState(() => _day = day),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Legend(color: AppColors.recording, label: l.calendarFull),
            _Legend(
              color: AppColors.passage,
              label: l.calendarPartial,
              dot: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.calendarGoTo, style: text.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  '${DateFormat.yMd(locale).format(_day)} · '
                  '${DateFormat.Hm(locale).format(_at(_day, _time))}',
                ),
                onPressed: _pickTime,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _close(_chosen),
              child: Text(l.calendarGo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (label, time) in shortcuts)
              ActionChip(label: Text(label), onPressed: () => _close(time)),
          ],
        ),
        if (oldest != null) ...[
          const SizedBox(height: 8),
          Text(
            l.calendarOldestAt(
              '${DateFormat.MMMEd(locale).format(oldest)} '
              '${DateFormat.Hm(locale).format(oldest)}',
            ),
            style: text.bodySmall?.copyWith(color: AppColors.textDim),
          ),
        ],
      ],
    );
  }

  DateTime _firstMonth(RecordingHistory history, DateTime now) {
    var first = history.oldest;
    for (final day in history.days.keys) {
      if (first == null || day.isBefore(first)) first = day;
    }
    first ??= now;
    if (_day.isBefore(first)) first = _day;
    return DateTime(first.year, first.month);
  }

  static DateTime _at(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final RecordingHistory history;
  final DateTime selected;
  final ValueChanged<DateTime> onDay;

  const _MonthGrid({
    required this.month,
    required this.history,
    required this.selected,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final firstWeekday = material.firstDayOfWeekIndex; // 0 = Sunday.
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (month.weekday % 7 - firstWeekday) % 7;
    final cells = <Widget>[
      for (var i = 0; i < 7; i++)
        Center(
          child: Text(
            material.narrowWeekdays[(firstWeekday + i) % 7],
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _dayCell(DateTime(month.year, month.month, d)),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      children: cells,
    );
  }

  Widget _dayCell(DateTime day) {
    final recording = history.at(day);
    final isSelected = DateUtils.isSameDay(day, selected);
    final background = isSelected
        ? AppColors.accent
        : recording == DayRecording.full
        ? AppColors.recording
        : null;
    final foreground = isSelected
        ? AppColors.background
        : recording == null
        ? AppColors.textDim.withValues(alpha: 0.4)
        : Colors.white;
    return Material(
      color: background ?? Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: recording == null ? null : () => onDay(day),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: foreground,
                fontWeight: isSelected ? FontWeight.w600 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (recording == DayRecording.partial)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.background
                        : AppColors.passage,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dot;

  const _Legend({required this.color, required this.label, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final size = dot ? 6.0 : 10.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(dot ? size : 3),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ),
      ],
    );
  }
}
