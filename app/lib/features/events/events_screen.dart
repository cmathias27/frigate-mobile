import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import '../timeline/motion_passages.dart';
import 'motion_list.dart';
import 'thumbnails.dart';

/// "42 s", "1 min 05", "2 h 10".
String formatPassageDuration(Duration d, AppLocalizations l) {
  final seconds = d.inSeconds < 1 ? 1 : d.inSeconds;
  if (seconds < 60) return l.durationSeconds(seconds);
  String two(int v) => v.toString().padLeft(2, '0');
  if (seconds < 3600) {
    return l.durationMinutes(seconds ~/ 60, two(seconds % 60));
  }
  return l.durationHours(seconds ~/ 3600, two(seconds % 3600 ~/ 60));
}

/// Alerts tab (mock-up screen 5): the motion passages of every camera,
/// newest first, by day. Opening one plays it in the timeline.
class EventsScreen extends StatefulWidget {
  final List<CameraCapabilities> cameras;
  final MotionList list;
  final RecordingThumbnails thumbnails;
  final void Function(MotionPassage passage) onOpen;
  final DateTime Function()? clock;

  const EventsScreen({
    super.key,
    required this.cameras,
    required this.list,
    required this.thumbnails,
    required this.onOpen,
    this.clock,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.list.open());
  }

  @override
  void dispose() {
    // Leaving the tab: what was listed has been seen.
    unawaited(widget.list.markSeen());
    super.dispose();
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final labels = {for (final c in widget.cameras) c.name: c.label};

    return ListenableBuilder(
      listenable: widget.list,
      builder: (context, _) {
        final list = widget.list;
        final passages = list.passages;
        final from = list.from;
        final newCount = list.newCount;
        final fromText = from == null ? '' : _dayTime(from, locale, l);

        final rows = <Widget>[];
        DateTime? day;
        for (final p in passages) {
          final d = DateTime(p.start.year, p.start.month, p.start.day);
          if (d != day) {
            day = d;
            rows.add(_DaySeparator(_dayLabel(d, locale, l)));
          }
          rows.add(
            _PassageRow(
              key: ValueKey('${p.camera}@${p.start.millisecondsSinceEpoch}'),
              passage: p,
              label: labels[p.camera] ?? p.camera,
              isNew: list.isNew(p),
              thumbnails: widget.thumbnails,
              onTap: () => widget.onOpen(p),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.cameras.length > 1)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  children: [
                    for (final (name, label) in [
                      (null, l.eventsAllCameras),
                      for (final c in widget.cameras) (c.name, c.label),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: list.camera == name,
                          onSelected: (_) => list.camera = name,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                newCount > 0
                    ? l.eventsNewCount(newCount)
                    : from == null
                    ? ''
                    : l.eventsSince(fromText),
                style: text.bodySmall?.copyWith(
                  color: newCount > 0 ? AppColors.passage : AppColors.textDim,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: list.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    ...rows,
                    if (passages.isEmpty && from != null && !list.loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l.eventsEmpty(fromText),
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.textDim,
                          ),
                        ),
                      ),
                    _Footer(list: list),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _dayLabel(DateTime day, String locale, AppLocalizations l) {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l.eventsToday;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l.eventsYesterday;
    }
    return DateFormat.MMMMEEEEd(locale).format(day);
  }

  String _dayTime(DateTime time, String locale, AppLocalizations l) {
    final day = DateTime(time.year, time.month, time.day);
    final hour = DateFormat.Hm(locale).format(time);
    final now = _now();
    if (day == DateTime(now.year, now.month, now.day)) return hour;
    return '${_dayLabel(day, locale, l).toLowerCase()} $hour';
  }
}

class _DaySeparator extends StatelessWidget {
  final String label;
  const _DaySeparator(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textDim,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// One passage: recorded frame from its middle, camera, time and length.
class _PassageRow extends StatelessWidget {
  final MotionPassage passage;
  final String label;
  final bool isNew;
  final RecordingThumbnails thumbnails;
  final VoidCallback onTap;

  const _PassageRow({
    super.key,
    required this.passage,
    required this.label,
    required this.isNew,
    required this.thumbnails,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final middle = passage.start.add(passage.duration ~/ 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.passage, width: 3),
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Row(
              spacing: 10,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: _Thumbnail(
                      future: thumbnails.of(
                        passage.camera,
                        DateTime.fromMillisecondsSinceEpoch(
                          middle.millisecondsSinceEpoch ~/ 1000 * 1000,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        l.eventsPassageTitle(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${DateFormat.Hms(locale).format(passage.start)}'
                        ' · ${formatPassageDuration(passage.duration, l)}',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.eventsNew,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.passage,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Future<Uint8List> future;
  const _Thumbnail({required this.future});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceHigh,
      child: FutureBuilder<Uint8List>(
        future: future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return snapshot.hasError
                ? const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.textDim,
                    size: 20,
                  )
                : const SizedBox.shrink();
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

/// End of the list: loading, failure, more hours, or the start of history.
class _Footer extends StatelessWidget {
  final MotionList list;
  const _Footer({required this.list});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final Widget child;
    if (list.loading) {
      child = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (list.failed) {
      child = Column(
        spacing: 4,
        children: [
          Text(
            l.eventsLoadFailed,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textDim),
          ),
          TextButton(onPressed: list.retry, child: Text(l.timelineRetry)),
        ],
      );
    } else if (list.reachedEnd) {
      child = Text(
        l.eventsHistoryStart,
        style: text.bodySmall?.copyWith(color: AppColors.textDim),
      );
    } else {
      child = OutlinedButton(
        onPressed: list.loadMore,
        child: Text(l.eventsLoadMore(MotionListDefaults.page)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: child),
    );
  }
}
