import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/formatting.dart';
import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../core/frigate/reviews.dart';
import '../../l10n/app_localizations.dart';
import 'events_screen.dart';
import 'review_list.dart';

/// Alerts tab when Frigate tracks objects or sounds (mock-up screen 5):
/// alerts, detections, or the motion passages, by a segmented control.
class AlertsScreen extends StatelessWidget {
  final ReviewList reviews;
  final ReviewThumbnails thumbnails;

  /// Cameras whose alerts and detections are listed.
  final List<CameraCapabilities> cameras;

  /// The motion passages, as without detection.
  final WidgetBuilder motion;

  /// An item opened: already marked seen.
  final void Function(ReviewItem item) onOpen;
  final DateTime Function()? clock;

  const AlertsScreen({
    super.key,
    required this.reviews,
    required this.thumbnails,
    required this.cameras,
    required this.motion,
    required this.onOpen,
    this.clock,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: reviews,
      builder: (context, _) {
        final view = reviews.view;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: SegmentedButton<EventsView>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: EventsView.alerts,
                    label: _SegmentLabel(
                      l.alertsViewAlerts,
                      reviews.unseen(ReviewSeverity.alert),
                    ),
                  ),
                  ButtonSegment(
                    value: EventsView.detections,
                    label: _SegmentLabel(
                      l.alertsViewDetections,
                      reviews.unseen(ReviewSeverity.detection),
                    ),
                  ),
                  ButtonSegment(
                    value: EventsView.motion,
                    label: Text(l.alertsViewMotion),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (s) => reviews.view = s.first,
              ),
            ),
            Expanded(
              child: switch (view) {
                EventsView.motion => motion(context),
                EventsView.alerts => ReviewView(
                  key: const ValueKey(ReviewSeverity.alert),
                  severity: ReviewSeverity.alert,
                  reviews: reviews,
                  thumbnails: thumbnails,
                  cameras: cameras,
                  onOpen: onOpen,
                  clock: clock,
                ),
                EventsView.detections => ReviewView(
                  key: const ValueKey(ReviewSeverity.detection),
                  severity: ReviewSeverity.detection,
                  reviews: reviews,
                  thumbnails: thumbnails,
                  cameras: cameras,
                  onOpen: onOpen,
                  clock: clock,
                ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final String label;
  final int unseen;
  const _SegmentLabel(this.label, this.unseen);

  @override
  Widget build(BuildContext context) {
    if (unseen == 0) return Text(label, maxLines: 1);
    return Badge(
      label: Text('$unseen'),
      backgroundColor: AppColors.live,
      offset: const Offset(14, -6),
      child: Text(label, maxLines: 1),
    );
  }
}

/// Alerts or detections, newest first by day: swipe to mark seen (or not
/// seen), long press to select several, touch to play in the timeline.
class ReviewView extends StatefulWidget {
  final ReviewSeverity severity;
  final ReviewList reviews;
  final ReviewThumbnails thumbnails;
  final List<CameraCapabilities> cameras;
  final void Function(ReviewItem item) onOpen;
  final DateTime Function()? clock;

  const ReviewView({
    super.key,
    required this.severity,
    required this.reviews,
    required this.thumbnails,
    required this.cameras,
    required this.onOpen,
    this.clock,
  });

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    // After the first frame: the list notifies as soon as it starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.reviews.open());
    });
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  Future<void> _mark(Iterable<ReviewItem> items, {bool reviewed = true}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).reviewMarkFailed;
    final ok = await widget.reviews.mark(items, reviewed: reviewed);
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }

  void _toggle(ReviewItem item) => setState(() {
    if (!_selected.remove(item.id)) _selected.add(item.id);
  });

  void _open(ReviewItem item) {
    unawaited(_mark([item]));
    widget.onOpen(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final labels = {for (final c in widget.cameras) c.name: c.label};

    return ListenableBuilder(
      listenable: widget.reviews,
      builder: (context, _) {
        final list = widget.reviews;
        final items = list.items(widget.severity);
        _selected.retainWhere((id) => items.any((i) => i.id == id));
        final selected = [
          for (final i in items)
            if (_selected.contains(i.id)) i,
        ];
        final unseen = list.unseen(widget.severity);
        final from = list.from;
        final fromText = from == null
            ? ''
            : eventsDayTime(from, _now(), locale, l);

        final rows = <Widget>[];
        DateTime? day;
        for (final item in items) {
          final d = DateTime(item.start.year, item.start.month, item.start.day);
          if (d != day) {
            day = d;
            rows.add(DaySeparator(eventsDayLabel(d, _now(), locale, l)));
          }
          rows.add(
            _ReviewRow(
              key: ValueKey(item.id),
              item: item,
              camera: labels[item.camera] ?? item.camera,
              selected: _selected.contains(item.id),
              thumbnails: widget.thumbnails,
              onTap: _selected.isEmpty
                  ? () => _open(item)
                  : () => _toggle(item),
              onLongPress: () => _toggle(item),
              onSwipe: () => _mark([item], reviewed: !item.reviewed),
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
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.isNotEmpty
                            ? l.reviewSelected(selected.length)
                            : unseen > 0
                            ? l.reviewUnseen(unseen)
                            : from == null
                            ? ''
                            : l.reviewSince(fromText),
                        style: text.bodySmall?.copyWith(
                          color: selected.isEmpty && unseen > 0
                              ? AppColors.live
                              : AppColors.textDim,
                        ),
                      ),
                    ),
                    if (selected.isNotEmpty) ...[
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: Text(l.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          final all = selected.every((i) => i.reviewed);
                          setState(_selected.clear);
                          unawaited(_mark(selected, reviewed: !all));
                        },
                        child: Text(
                          selected.every((i) => i.reviewed)
                              ? l.reviewMarkUnseen
                              : l.reviewMarkSeen,
                        ),
                      ),
                    ] else if (unseen > 0)
                      TextButton(
                        onPressed: () => _mark(
                          items.where((i) => !i.reviewed),
                        ),
                        child: Text(l.reviewMarkAllSeen),
                      ),
                  ],
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
                    if (items.isEmpty && from != null && !list.loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          widget.severity == ReviewSeverity.alert
                              ? l.reviewEmptyAlerts(fromText)
                              : l.reviewEmptyDetections(fromText),
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.textDim,
                          ),
                        ),
                      ),
                    _ReviewFooter(list: list),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One alert or detection: thumbnail, what and where, time, length, zones.
class _ReviewRow extends StatelessWidget {
  final ReviewItem item;
  final String camera;
  final bool selected;
  final ReviewThumbnails thumbnails;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSwipe;

  const _ReviewRow({
    super.key,
    required this.item,
    required this.camera,
    required this.selected,
    required this.thumbnails,
    required this.onTap,
    required this.onLongPress,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final what = item.labels.isEmpty
        ? l.reviewUnknown
        : item.labels.map((label) => objectLabel(label, l)).join(', ');
    final duration = item.duration;
    final details = [
      DateFormat.Hms(locale).format(item.start),
      duration == null ? l.reviewInProgress : formatDuration(duration, l),
      if (item.zones.isNotEmpty) item.zones.map(_spaced).join(', '),
    ].join(' · ');
    final thumbnail = item.thumbnail;

    final swipeHint = Container(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        spacing: 8,
        children: [
          Icon(
            item.reviewed ? Icons.visibility_off_outlined : Icons.done_all,
            color: AppColors.accent,
          ),
          Text(item.reviewed ? l.reviewMarkUnseen : l.reviewMarkSeen),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Dismissible(
          key: ValueKey('swipe-${item.id}'),
          background: swipeHint,
          secondaryBackground: Directionality(
            textDirection: TextDirection.rtl,
            child: swipeHint,
          ),
          // The row stays: swiping only changes its mark.
          confirmDismiss: (_) async {
            onSwipe();
            return false;
          },
          child: Opacity(
            opacity: item.reviewed && !selected ? 0.62 : 1,
            child: Material(
              color: selected ? AppColors.surfaceHigh : AppColors.surface,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: reviewColor(item), width: 3),
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
                          child: selected
                              ? const ColoredBox(
                                  color: AppColors.accent,
                                  child: Icon(Icons.check, color: Colors.white),
                                )
                              : thumbnail == null
                              ? const ColoredBox(color: AppColors.surfaceHigh)
                              : EventThumbnail(
                                  future: thumbnails.of(thumbnail),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              l.reviewTitle(what, camera),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.subLabels.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 96),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.subLabels.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: AppColors.face,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// End of the list: loading, failure, the day before, or history start.
class _ReviewFooter extends StatelessWidget {
  final ReviewList list;
  const _ReviewFooter({required this.list});

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
        children: [
          Text(
            l.reviewLoadFailed,
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
        child: Text(l.reviewLoadMore),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: child),
    );
  }
}

const _vehicles = {'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'boat'};

/// Colour of the left border: a person, a vehicle, a recognised face or
/// plate, otherwise the accent.
Color reviewColor(ReviewItem item) {
  if (item.subLabels.isNotEmpty) return AppColors.face;
  if (item.labels.contains('person')) return AppColors.person;
  if (item.labels.any(_vehicles.contains)) return AppColors.vehicle;
  return AppColors.accent;
}

/// Name of a Frigate label in the language of the app; a label the app
/// does not know is shown as Frigate writes it, underscores as spaces.
String objectLabel(String label, AppLocalizations l) => switch (label) {
  'person' => l.objectPerson,
  'car' => l.objectCar,
  'truck' => l.objectTruck,
  'bus' => l.objectBus,
  'motorcycle' => l.objectMotorcycle,
  'bicycle' => l.objectBicycle,
  'boat' => l.objectBoat,
  'dog' => l.objectDog,
  'cat' => l.objectCat,
  'bird' => l.objectBird,
  'horse' => l.objectHorse,
  'package' => l.objectPackage,
  'face' => l.objectFace,
  'license_plate' => l.objectLicensePlate,
  'bark' => l.objectBark,
  'speech' => l.objectSpeech,
  'scream' => l.objectScream,
  'fire_alarm' => l.objectFireAlarm,
  _ => _capitalized(_spaced(label)),
};

String _spaced(String name) => name.replaceAll('_', ' ');

String _capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
