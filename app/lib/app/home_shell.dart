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
import '../features/more/settings_screen.dart';
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
import 'app_settings.dart';
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
  static const _keyLiveGroup = 'fm_live_group';

  /// Group shown in the live view, `null` for every camera.
  String? _liveGroup;

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
  late final AppSettings _settings = AppSettings(_preferences);

  /// Cameras the recordings and the reviews were prepared for.
  String? _timelineCameras;
  String? _reviewCameras;

  /// Passage opened from the Alerts tab, played once by the timeline.
  MotionPassage? _openAt;

  /// False until the settings are read: cameras would otherwise show
  /// first in the default order, hidden ones included.
  bool _settingsReady = false;

  @override
  void initState() {
    super.initState();
    _readLiveLayout();
    _settings.addListener(_onSettings);
    unawaited(
      _settings.load().whenComplete(() {
        if (mounted) setState(() => _settingsReady = true);
      }),
    );
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
    final group = await _preferences.read(_keyLiveGroup);
    if (!mounted) return;
    setState(() {
      if (stored != null && liveLayouts.contains(stored)) _liveLayout = stored;
      _liveGroup = group;
    });
  }

  void _setLiveGroup(String? group) {
    setState(() => _liveGroup = group);
    unawaited(_preferences.write(_keyLiveGroup, group));
  }

  Widget _live(FrigateClient client, List<CameraCapabilities> cameras) {
    final l = AppLocalizations.of(context);
    final groups = _settings.groups;
    // A group removed or renamed since: every camera.
    final group = _settings.group(_liveGroup);
    final shown = group == null
        ? cameras
        : [
            for (final c in cameras)
              if (group.cameras.contains(c.name)) c,
          ];
    return Column(
      children: [
        if (groups.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                for (final (name, label) in [
                  (null, l.liveGroupAll),
                  for (final g in groups) (g.name, g.name),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: group?.name == name,
                      onSelected: (_) => _setLiveGroup(name),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: shown.isEmpty
              ? _Placeholder(
                  icon: Icons.videocam_off_outlined,
                  description: l.liveGroupEmpty,
                )
              : LiveGridScreen(
                  key: ValueKey(group?.name),
                  cameras: shown,
                  fetch: client.fetchLatestImage,
                  videoFactory: _settings.liveMode == LiveMode.images
                      ? null
                      : (stream) => WebRtcLiveVideo(
                          stream: stream,
                          negotiate: client.negotiateWebRtc,
                        ),
                  layout: _liveLayout,
                  onAuthError: widget.controller.sessionExpired,
                  minTileWidth: _settings.tileSize.width,
                  lightStreamFirst: _settings.fullScreenLightFirst,
                  tryOtherStreams: _settings.tryOtherStreams,
                  videoOnly: _settings.liveMode == LiveMode.video,
                ),
        ),
      ],
    );
  }

  void _setLiveLayout(int layout) {
    setState(() => _liveLayout = layout);
    _preferences.write(_keyLiveLayout, '$layout');
  }

  void _onSettings() {
    _timelineData?.settings = _settings.passages;
    if (mounted) setState(() {});
  }

  /// Automatic motion threshold of [camera] among the recordings fetched.
  int? _autoThreshold(String camera) {
    final segments = _timelineData?.segments(camera) ?? const [];
    if (segments.isEmpty) return null;
    return passageThreshold(segments.map((s) => s.motion));
  }

  @override
  void dispose() {
    _releaseTimeline();
    _releaseReviews();
    _settings.removeListener(_onSettings);
    _settings.dispose();
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
    _timelineCameras = null;
  }

  void _releaseReviews() {
    _reviewList?.dispose();
    _reviewList = null;
    _reviewThumbnails = null;
    _reviewClient = null;
    _reviewCameras = null;
  }

  /// Alerts and detections of the session, kept across tab changes.
  void _prepareReviews(
    FrigateClient client,
    List<CameraCapabilities> reviewed,
  ) {
    final names = reviewed.map((c) => c.name).join(',');
    if (identical(client, _reviewClient) && names == _reviewCameras) return;
    _releaseReviews();
    _reviewClient = client;
    _reviewCameras = names;
    _reviewList = ReviewList(
      fetch: client.fetchReviews,
      mark: client.markReviewed,
      cameras: [for (final c in reviewed) c.name],
      history: historySpan(
        reviewed.map((c) => c.retentionDays),
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
    final names = recorded.map((c) => c.name).join(',');
    if (identical(client, _timelineClient) && names == _timelineCameras) {
      return;
    }
    _releaseTimeline();
    _timelineClient = client;
    _timelineCameras = names;
    final data = _timelineData = TimelineData(
      cameras: [for (final c in recorded) c.name],
      fetch: client.fetchRecordings,
      settings: _settings.passages,
      onAuthError: widget.controller.sessionExpired,
    );
    _vodProxy = VodProxy(
      client.openStream,
      onAuthError: widget.controller.sessionExpired,
    );
    _motionList = MotionList(
      data: data,
      history: historySpan(
        recorded.map((c) => c.retentionDays),
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

  Widget _settingsEntry(
    AppLocalizations l,
    List<CameraCapabilities> cameras,
  ) => ListTile(
    leading: const Icon(Icons.tune_rounded),
    title: Text(l.settingsTitle),
    subtitle: Text(l.settingsSubtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    tileColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: _settings,
          cameras: cameras,
          autoThreshold: _autoThreshold,
        ),
      ),
    ),
  );

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
        enabled: _settings.imageFallback,
      ),
      loadHistory: () => _loadHistory(client, recorded),
      openAt: openAt,
      preferences: _preferences,
      live: LiveSource(
        fetch: client.fetchLatestImage,
        videoFactory: _settings.liveMode == LiveMode.images
            ? null
            : (stream) => WebRtcLiveVideo(
                stream: stream,
                negotiate: client.negotiateWebRtc,
              ),
        onAuthError: widget.controller.sessionExpired,
        lightStreamFirst: _settings.timelineLightFirst,
        tryOtherStreams: _settings.tryOtherStreams,
        videoOnly: _settings.liveMode == LiveMode.video,
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
        if (recorded.any((c) => c.name == item.camera)) {
          _openReview(item);
          return;
        }
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.alertNoRecording)));
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
    if (!_settingsReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final serverName = widget.controller.config?.name ?? l.appTitle;
    final allCameras =
        widget.controller.capabilities?.cameras.values.toList() ?? const [];
    // In the order chosen, hidden ones left out (settings).
    final cameras = _settings.arrange(allCameras);
    final cameraCount = cameras.length;
    final client = widget.controller.client;

    final tabs = [
      (l.tabLive, Icons.grid_view_rounded, l.liveDescription),
      (l.tabTimeline, Icons.timeline_rounded, l.timelineDescription),
      (l.tabEvents, Icons.notifications_none_rounded, l.eventsDescription),
      (l.tabMore, Icons.menu_rounded, l.moreDescription),
    ];
    final (title, _, _) = tabs[_index];

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
        0 when client != null => _live(client, cameras),
        1 when client != null => _timeline(client, cameras),
        2 when client != null => _events(client, cameras),
        3 => MoreScreen(
          controller: widget.controller,
          appVersion: widget.update?.currentVersion,
          updates: widget.update == null
              ? null
              : UpdateSettings(update: widget.update!),
          settings: _settingsEntry(l, allCameras),
        ),
        // Only between a lost session and the login screen.
        _ => _Placeholder(
          icon: Icons.cloud_off_rounded,
          description: l.serverNotConnected,
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

  const _Placeholder({required this.icon, required this.description});

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}
