import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/frigate/capabilities.dart';
import '../core/frigate/client.dart';
import '../core/frigate/reviews.dart';
import '../core/frigate/vod_proxy.dart';
import '../core/session/session_controller.dart';
import '../core/storage/preferences.dart';
import '../features/events/alerts_screen.dart';
import '../features/events/events_screen.dart';
import '../features/events/motion_list.dart';
import '../features/events/review_list.dart';
import '../features/events/thumbnails.dart';
import '../features/live/live_grid_screen.dart';
import '../features/live/live_pane.dart';
import '../features/live/webrtc_live_video.dart';
import '../features/more/more_screen.dart';
import '../features/timeline/clip_sheet.dart';
import '../features/timeline/image_playback.dart';
import '../features/timeline/motion_passages.dart';
import '../features/timeline/recording_history.dart';
import '../features/timeline/recording_player.dart';
import '../features/timeline/timeline_data.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/update/update_controller.dart';
import '../features/update/update_widgets.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// The four tabs of the mock-ups.
class HomeShell extends StatefulWidget {
  final SessionController controller;

  /// In-app update; none in tests.
  final UpdateController? update;

  /// Small settings of the app; in memory in tests.
  final Preferences? preferences;

  const HomeShell({
    super.key,
    required this.controller,
    this.update,
    this.preferences,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _liveLayout = liveLayoutDefault;
  static const _keyLiveLayout = 'fm_live_layout';

  // Kept across tab changes so the hours fetched stay cached.
  FrigateClient? _timelineClient;
  TimelineData? _timelineData;
  VodProxy? _vodProxy;
  MotionList? _motionList;
  RecordingThumbnails? _thumbnails;
  FrigateClient? _reviewClient;
  ReviewList? _reviewList;
  ReviewThumbnails? _reviewThumbnails;
  late final Preferences _preferences = widget.preferences ?? Preferences();

  /// Passage opened from the Alerts tab, played once by the timeline.
  MotionPassage? _openAt;

  @override
  void initState() {
    super.initState();
    _readLiveLayout();
    final update = widget.update;
    if (update != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(runStartupUpdate(context, update));
      });
    }
  }

  Future<void> _readLiveLayout() async {
    final stored = int.tryParse(
      await _preferences.read(_keyLiveLayout) ?? '',
    );
    if (stored == null || !liveLayouts.contains(stored) || !mounted) return;
    setState(() => _liveLayout = stored);
  }

  void _setLiveLayout(int layout) {
    setState(() => _liveLayout = layout);
    _preferences.write(_keyLiveLayout, '$layout');
  }

  @override
  void dispose() {
    _releaseTimeline();
    _releaseReviews();
    super.dispose();
  }

  void _releaseTimeline() {
    _motionList?.dispose();
    _timelineData?.dispose();
    _vodProxy?.close();
    _motionList = null;
    _thumbnails = null;
    _timelineData = null;
    _vodProxy = null;
    _timelineClient = null;
  }

  void _releaseReviews() {
    _reviewList?.dispose();
    _reviewList = null;
    _reviewThumbnails = null;
    _reviewClient = null;
  }

  /// Alerts and detections of the session, kept across tab changes.
  void _prepareReviews(
    FrigateClient client,
    List<CameraCapabilities> reviewed,
  ) {
    if (identical(client, _reviewClient)) return;
    _releaseReviews();
    _reviewClient = client;
    _reviewList = ReviewList(
      fetch: client.fetchReviews,
      mark: client.markReviewed,
      cameras: [for (final c in reviewed) c.name],
      history: historySpan(
        reviewed.expand((c) => [c.alertDays, c.continuousDays, c.motionDays]),
      ),
    );
    _reviewThumbnails = ReviewThumbnails(client.fetchReviewThumbnail);
  }

  /// Recordings of the session, shared by the timeline and the Alerts tab
  /// so an hour is fetched once.
  void _prepareRecordings(
    FrigateClient client,
    List<CameraCapabilities> recorded,
  ) {
    if (identical(client, _timelineClient)) return;
    _releaseTimeline();
    _timelineClient = client;
    final data = _timelineData = TimelineData(
      cameras: [for (final c in recorded) c.name],
      fetch: client.fetchRecordings,
      onAuthError: widget.controller.sessionExpired,
    );
    _vodProxy = VodProxy(
      client.openStream,
      onAuthError: widget.controller.sessionExpired,
    );
    _motionList = MotionList(
      data: data,
      history: historySpan(
        recorded.expand((c) => [c.continuousDays, c.motionDays]),
      ),
      preferences: _preferences,
    );
    _thumbnails = RecordingThumbnails(
      (camera, time) => client.fetchRecordingImage(
        camera,
        time,
        height: ThumbnailDefaults.height,
      ),
    );
  }

  Widget _noRecording() => _Placeholder(
    icon: Icons.videocam_off_outlined,
    description: AppLocalizations.of(context).timelineNoRecordingCamera,
  );

  Widget _timeline(FrigateClient client, List<CameraCapabilities> cameras) {
    final recorded = cameras.where((c) => c.recording).toList();
    if (recorded.isEmpty) return _noRecording();
    _prepareRecordings(client, recorded);
    final proxy = _vodProxy!;
    final openAt = _openAt;
    _openAt = null;
    return TimelineScreen(
      cameras: recorded,
      data: _timelineData!,
      playerFactory: () => FallbackRecordingPlayer(
        video: HlsRecordingPlayer(proxy),
        images: ImageRecordingPlayer(client.fetchRecordingImage),
      ),
      loadHistory: () => _loadHistory(client, recorded),
      openAt: openAt,
      preferences: _preferences,
      live: LiveSource(
        fetch: client.fetchLatestImage,
        videoFactory: (stream) =>
            WebRtcLiveVideo(stream: stream, negotiate: client.negotiateWebRtc),
        onAuthError: widget.controller.sessionExpired,
      ),
      export: RecordingExport(
        open: client.openStream,
        frame: client.fetchRecordingImage,
        cacheDirectory: getTemporaryDirectory,
        onAuthError: widget.controller.sessionExpired,
      ),
    );
  }

  Widget _events(FrigateClient client, List<CameraCapabilities> cameras) {
    final recorded = cameras.where((c) => c.recording).toList();
    // Alerts and detections only where Frigate makes them (decision 0002).
    final reviewed = cameras
        .where((c) => c.objectDetection || c.audioDetection)
        .toList();
    if (reviewed.isEmpty) return _motionEvents(client, recorded);
    _prepareReviews(client, reviewed);
    return AlertsScreen(
      reviews: _reviewList!,
      thumbnails: _reviewThumbnails!,
      cameras: reviewed,
      motion: (_) => _motionEvents(client, recorded),
      onOpen: (item) {
        if (!recorded.any((c) => c.name == item.camera)) return;
        _openReview(item);
      },
    );
  }

  /// Plays an alert or a detection in the timeline, like a passage.
  void _openReview(ReviewItem item) => setState(() {
    _openAt = MotionPassage(
      camera: item.camera,
      start: item.start,
      end: item.end ?? DateTime.now(),
      peak: 0,
    );
    _index = 1;
  });

  Widget _motionEvents(
    FrigateClient client,
    List<CameraCapabilities> recorded,
  ) {
    if (recorded.isEmpty) return _noRecording();
    _prepareRecordings(client, recorded);
    return EventsScreen(
      cameras: recorded,
      list: _motionList!,
      thumbnails: _thumbnails!,
      onOpen: (passage) => setState(() {
        _openAt = passage;
        _index = 1;
      }),
    );
  }

  Future<RecordingHistory> _loadHistory(
    FrigateClient client,
    List<CameraCapabilities> cameras,
  ) async {
    try {
      return await loadRecordingHistory(
        cameras: [for (final c in cameras) c.name],
        fetchHours: client.fetchRecordingHours,
        fetchSegments: client.fetchRecordings,
      );
    } on FrigateAuthException {
      unawaited(widget.controller.sessionExpired());
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final serverName = widget.controller.config?.name ?? l.appTitle;
    final cameras =
        widget.controller.capabilities?.cameras.values.toList() ?? const [];
    final cameraCount = cameras.length;
    final client = widget.controller.client;

    final tabs = [
      (l.tabLive, Icons.grid_view_rounded, l.liveDescription),
      (l.tabTimeline, Icons.timeline_rounded, l.timelineDescription),
      (l.tabEvents, Icons.notifications_none_rounded, l.eventsDescription),
      (l.tabMore, Icons.menu_rounded, l.moreDescription),
    ];
    final (title, icon, description) = tabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _index == 3 ? title : serverName,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_index != 3 && cameraCount > 0)
              Text(
                l.serverInfoCameras(cameraCount),
                style: text.bodySmall?.copyWith(color: AppColors.textDim),
              ),
          ],
        ),
        actions: [
          if (_index == 0)
            for (final layout in liveLayouts)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _LayoutButton(
                  layout: layout,
                  selected: layout == _liveLayout,
                  onPressed: () => _setLiveLayout(layout),
                ),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (_index) {
        0 when client != null => LiveGridScreen(
          cameras: cameras,
          fetch: client.fetchLatestImage,
          videoFactory: (stream) => WebRtcLiveVideo(
            stream: stream,
            negotiate: client.negotiateWebRtc,
          ),
          layout: _liveLayout,
          onAuthError: widget.controller.sessionExpired,
        ),
        1 when client != null => _timeline(client, cameras),
        2 when client != null => _events(client, cameras),
        3 => MoreScreen(
          controller: widget.controller,
          appVersion: widget.update?.currentVersion,
          updates: widget.update == null
              ? null
              : UpdateSettings(update: widget.update!),
        ),
        _ => _Placeholder(
          icon: icon,
          description: description,
          version: '0.1',
        ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (label, icon, _) in tabs)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}

/// "Auto", "1", "4" or "9" button of the live grid layouts (mock-up
/// screen 2).
class _LayoutButton extends StatelessWidget {
  final int layout;
  final bool selected;
  final VoidCallback onPressed;

  const _LayoutButton({
    required this.layout,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auto = layout == liveLayoutAuto;
    final color = selected ? AppColors.background : null;
    return Tooltip(
      message: auto ? l.liveLayoutAuto : l.liveLayout(layout),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: auto
                    ? Icon(
                        Icons.auto_awesome_mosaic_rounded,
                        size: 18,
                        color: color,
                      )
                    : Text(
                        '$layout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
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

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String description;
  final String? version;

  const _Placeholder({
    required this.icon,
    required this.description,
    this.version,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(icon, size: 48, color: AppColors.textDim),
            Text(
              description,
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            if (version case final version?)
              Text(
                l.comingInVersion(version),
                style: text.bodySmall?.copyWith(color: AppColors.textDim),
              ),
          ],
        ),
      ),
    );
  }
}
