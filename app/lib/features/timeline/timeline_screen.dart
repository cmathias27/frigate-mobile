import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../core/storage/preferences.dart';
import '../../l10n/app_localizations.dart';
import '../live/live_pane.dart';
import '../live/photo.dart';
import 'calendar_sheet.dart';
import 'clip_sheet.dart';
import 'motion_passages.dart';
import 'recording_history.dart';
import 'recording_player.dart';
import 'review_seek.dart';
import 'timeline_bands.dart';
import 'timeline_data.dart';

/// The same clock time [days] later, not [days] × 24 h: across a change
/// of the clocks the two differ by an hour.
DateTime shiftDay(DateTime t, int days) => DateTime(
  t.year,
  t.month,
  t.day + days,
  t.hour,
  t.minute,
  t.second,
  t.millisecond,
);

abstract final class TimelineScreenDefaults {
  /// Where the timeline opens: just behind the live edge.
  static const startBehindNow = Duration(minutes: 1);

  /// The newest few seconds are not written to disk yet.
  static const liveMargin = Duration(seconds: 10);

  /// Length of recording opened at once in the player.
  static const window = Duration(hours: 1);

  /// Jump of the back and forward buttons.
  static const jump = Duration(seconds: 10);

  /// Previous and next passage look at every camera rather than only the
  /// camera played (a setting kept on the phone).
  static const seekAllCameras = false;

  /// Previous and next go to Frigate's alerts and detections rather than
  /// to motion, when the server has them (a setting kept on the phone).
  static const seekReviews = false;

  /// Zoom chosen when the screen opens (index in [timelineZooms]).
  static const zoom = 1;

  /// Delay after a drag before the player opens the new time.
  static const settle = Duration(milliseconds: 350);

  /// The timeline opens on the live of the camera, like DS cam, rather than
  /// paused just behind it.
  static const openLive = true;

  /// Dragging or playing this close to the live edge goes live.
  static const liveSnap = Duration(seconds: 2);

  /// Playback speeds offered, and the one used when nothing was chosen.
  static const speeds = [0.5, 1.0, 2.0, 4.0, 8.0];
  static const speed = 1.0;
}

/// Timeline tab (mock-up screen 4): recordings of one camera played under
/// two bands, every camera and the camera played, with a common playhead.
abstract final class TimelineLayout {
  /// Most of the screen height given to the video, the rest to the controls.
  static const maxVideoShare = 0.6;
}

class TimelineScreen extends StatefulWidget {
  final List<CameraCapabilities> cameras;
  final TimelineData data;
  final RecordingPlayer Function() playerFactory;
  final DateTime Function()? clock;

  /// Reads every day recorded, for the calendar; no calendar without it.
  final Future<RecordingHistory> Function()? loadHistory;

  /// A passage opened from the Alerts tab, played as the timeline opens;
  /// otherwise the first camera, just behind the live edge.
  final MotionPassage? openAt;

  /// Clip and photo of the recording; neither is offered without it.
  final RecordingExport? export;

  /// Keeps the passage navigation mode; not kept without it.
  final Preferences? preferences;

  /// Live of the camera at the right end of the timeline; without it the
  /// timeline stops just behind now.
  final LiveSource? live;

  /// Alerts and detections for previous and next; motion only without it.
  final ReviewSeeker? reviews;

  const TimelineScreen({
    super.key,
    required this.cameras,
    required this.data,
    required this.playerFactory,
    this.clock,
    this.loadHistory,
    this.openAt,
    this.export,
    this.preferences,
    this.live,
    this.reviews,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with WidgetsBindingObserver {
  late final RecordingPlayer _player;
  late String _camera;
  late DateTime _playhead;
  int _zoom = TimelineScreenDefaults.zoom;
  bool _scrubbing = false;
  bool _resumeAfterScrub = false;
  bool _seeking = false;
  bool _atEnd = false;
  bool _wasPlaying = false;
  bool _takingPhoto = false;
  bool _seekAll = TimelineScreenDefaults.seekAllCameras;
  static const _keySeekAll = 'fm_timeline_seek_all';
  bool _seekReviews = TimelineScreenDefaults.seekReviews;
  static const _keySeekTarget = 'fm_timeline_seek_target';
  static const _keySpeed = 'fm_timeline_speed';
  Timer? _settle;

  /// The camera is shown live; the player stays closed meanwhile.
  bool _live = false;
  Timer? _liveTick;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  DateTime get _liveEdge => _now().subtract(TimelineScreenDefaults.liveMargin);

  Duration get _span =>
      timelineZooms[_zoom] ??
      historySpan(
        widget.cameras.map((c) => c.retentionDays),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final openAt = widget.openAt;
    final known = widget.cameras.any((c) => c.name == openAt?.camera);
    _camera = known ? openAt!.camera : widget.cameras.first.name;
    _playhead = known
        ? openAt!.start
        : _now().subtract(TimelineScreenDefaults.startBehindNow);
    _player = widget.playerFactory()..addListener(_onPlayer);
    widget.data.addListener(_onData);
    if (!known && TimelineScreenDefaults.openLive && widget.live != null) {
      _startLive();
      _ensure();
    } else {
      _ensure();
      _open(_playhead, play: known);
    }
    _readSeekMode();
  }

  Future<void> _readSeekMode() async {
    final stored = await widget.preferences?.read(_keySeekAll);
    if (stored != null && mounted) setState(() => _seekAll = stored == 'true');
    final target = await widget.preferences?.read(_keySeekTarget);
    if (target != null && mounted) {
      setState(() => _seekReviews = target == 'reviews');
    }
    final speed = double.tryParse(
      await widget.preferences?.read(_keySpeed) ?? '',
    );
    if (speed != null &&
        mounted &&
        TimelineScreenDefaults.speeds.contains(speed)) {
      await _player.setSpeed(speed);
    }
  }

  Future<void> _setSpeed(double speed) async {
    unawaited(widget.preferences?.write(_keySpeed, '$speed'));
    await _player.setSpeed(speed);
    // The player does not rebuild the screen while live.
    if (mounted) setState(() {});
  }

  void _setSeekAll(bool value) {
    setState(() => _seekAll = value);
    widget.preferences?.write(_keySeekAll, '$value');
  }

  void _setSeekReviews(bool value) {
    setState(() => _seekReviews = value);
    widget.preferences?.write(_keySeekTarget, value ? 'reviews' : 'motion');
  }

  /// Previous and next go to alerts and detections.
  bool get _onReviews => _seekReviews && widget.reviews != null;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settle?.cancel();
    _liveTick?.cancel();
    widget.data.removeListener(_onData);
    _player
      ..removeListener(_onPlayer)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _player.pause();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  /// Shows the camera live, the playhead following now.
  void _startLive() {
    _live = true;
    _atEnd = false;
    _playhead = _now();
    _liveTick?.cancel();
    _liveTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _playhead = _now());
    });
  }

  Future<void> _goLive() async {
    if (widget.live == null) return;
    setState(_startLive);
    _ensure();
    await _player.pause();
  }

  void _stopLive() {
    if (!_live) return;
    _live = false;
    _liveTick?.cancel();
    _liveTick = null;
    if (_playhead.isAfter(_liveEdge)) _playhead = _liveEdge;
  }

  /// [time] is at the live edge, where the live takes over.
  bool _atLive(DateTime time) =>
      widget.live != null &&
      !time.isBefore(_liveEdge.subtract(TimelineScreenDefaults.liveSnap));

  void _onPlayer() {
    if (!mounted) return;
    if (_live) return setState(() {});
    final time = _player.time;
    if (!_scrubbing &&
        _player.camera == _camera &&
        _player.status == PlayerStatus.ready &&
        time != null) {
      _playhead = time;
    }
    // Played to the end of the range opened (not paused there by hand).
    final ended = _wasPlaying && _player.completed && !_player.playing;
    _wasPlaying = _player.playing;
    if (ended && !_scrubbing) _continueAfter(_player.end);
    setState(() {});
  }

  /// The range opened has been played: open the next one, unless the live
  /// edge is reached.
  void _continueAfter(DateTime? end) {
    if (end == null || _player.status != PlayerStatus.ready) return;
    if (_liveEdge.difference(end) < TimelineScreenDefaults.jump) {
      if (widget.live != null) {
        _goLive();
      } else {
        _atEnd = true;
      }
      return;
    }
    _open(end, play: true);
  }

  void _ensure() {
    final half = _span ~/ 2;
    widget.data.ensure(
      _playhead.subtract(half),
      _playhead.add(half),
      focus: _camera,
    );
  }

  Future<void> _open(DateTime time, {bool play = false}) async {
    _stopLive();
    final edge = _liveEdge;
    if (time.isAfter(edge)) time = edge;
    _playhead = time;
    _atEnd = false;
    var end = time.add(TimelineScreenDefaults.window);
    if (end.isAfter(_now())) end = _now();
    await _player.open(_camera, time, end);
    if (play && mounted && _player.status == PlayerStatus.ready) {
      await _player.play();
    }
  }

  /// Moves the playhead to [time], seeking inside the range already open.
  Future<void> _goTo(DateTime time, {bool? play}) async {
    final shouldPlay = play ?? (_player.playing || _live);
    _stopLive();
    final start = _player.start;
    final end = _player.end;
    if (time.isAfter(_liveEdge)) time = _liveEdge;
    setState(() => _playhead = time);
    _ensure();
    if (_player.camera == _camera &&
        _player.status == PlayerStatus.ready &&
        start != null &&
        end != null &&
        !time.isBefore(start) &&
        time.isBefore(end)) {
      await _player.seek(time);
      if (shouldPlay) await _player.play();
    } else {
      await _open(time, play: shouldPlay);
    }
  }

  void _selectCamera(String camera, {DateTime? at}) {
    setState(() => _camera = camera);
    _ensure();
    if (_live && at == null) return;
    _open(at ?? _playhead, play: _player.playing || at != null);
  }

  Future<void> _seekPassage({required bool forward}) async {
    if (_seeking) return;
    setState(() => _seeking = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final camera = _seekAll ? null : _camera;
    final reviews = _onReviews ? widget.reviews : null;
    MotionPassage? passage;
    var failed = false;
    try {
      passage = reviews != null
          ? await reviews.seek(_playhead, forward: forward, camera: camera)
          : await widget.data.seekPassage(
              _playhead,
              forward: forward,
              camera: camera,
            );
    } catch (e) {
      debugPrint('Seek: $e');
      failed = true;
    }
    if (!mounted) return;
    setState(() => _seeking = false);
    if (passage == null) {
      final hours = TimelineDefaults.seekLimit.inHours;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failed
                ? l.reviewLoadFailed
                : reviews != null
                ? l.timelineNoReview(hours)
                : l.timelineNoPassage(hours),
          ),
        ),
      );
      return;
    }
    _jumpTo(passage);
  }

  void _jumpTo(MotionPassage passage) {
    if (passage.camera != _camera) {
      _selectCamera(passage.camera, at: passage.start);
    } else {
      _goTo(passage.start, play: true);
    }
  }

  Future<void> _togglePlay() async {
    // Pausing the live keeps the picture of now, from the recording.
    if (_live) return _open(_liveEdge);
    if (_player.playing) return _player.pause();
    if (_player.status == PlayerStatus.ready && _player.camera == _camera) {
      if (_player.completed || _atEnd) {
        return _open(_playhead, play: true);
      }
      return _player.play();
    }
    await _open(_playhead, play: true);
  }

  void _onScrubStart() {
    _settle?.cancel();
    _resumeAfterScrub = _player.playing || _live || _resumeAfterScrub;
    _scrubbing = true;
    setState(_stopLive);
    _player.pause();
  }

  void _onScrub(Duration delta) {
    var time = _playhead.add(delta);
    if (time.isAfter(_liveEdge)) time = _liveEdge;
    setState(() => _playhead = time);
  }

  void _onScrubEnd() {
    _ensure();
    _settle?.cancel();
    _settle = Timer(TimelineScreenDefaults.settle, () {
      _scrubbing = false;
      final play = _resumeAfterScrub;
      _resumeAfterScrub = false;
      if (_atLive(_playhead)) {
        _goLive();
      } else {
        _goTo(_playhead, play: play);
      }
    });
  }

  void _shiftDay(int days) => _goTo(shiftDay(_playhead, days), play: false);

  Future<void> _openCalendar() async {
    final load = widget.loadHistory;
    if (load == null) return;
    final time = await showRecordingCalendar(
      context,
      load: load,
      selected: _playhead,
      clock: widget.clock,
    );
    if (time != null && mounted) await _goTo(time, play: false);
  }

  void _setZoom(int index) {
    setState(() => _zoom = index);
    _ensure();
  }

  /// The passage of the camera played holding [time], if any.
  MotionPassage? _passageAt(DateTime time) {
    for (final p in widget.data.passages(_camera)) {
      if (!time.isBefore(p.start) && time.isBefore(p.end)) return p;
    }
    return null;
  }

  Future<void> _exportClip(RecordingExport export) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _player.pause();
    if (!mounted) return;
    final outcome = await showClipSheet(
      context,
      export: export,
      camera: _camera,
      label: _label(_camera),
      playhead: _live ? _liveEdge : _playhead,
      liveEdge: _liveEdge,
      passage: _passageAt(_playhead),
    );
    if (outcome == ClipOutcome.saved) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.clipSaved(DevicePhotoActions.album))),
      );
    }
  }

  /// Saves the recorded frame under the playhead, at full resolution.
  Future<void> _takePhoto(RecordingExport export) async {
    if (_takingPhoto) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final camera = _camera;
    final time = _live ? _liveEdge : _playhead;
    setState(() => _takingPhoto = true);
    try {
      final jpeg = await export.frame(camera, time);
      final name = photoName(camera, time);
      await export.photos.save(jpeg, name);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.livePhotoSaved(DevicePhotoActions.album)),
          action: SnackBarAction(
            label: l.livePhotoShare,
            onPressed: () => export.photos.share(jpeg, name),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Photo $camera: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.livePhotoFailed)));
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  String _label(String camera) {
    for (final c in widget.cameras) {
      if (c.name == camera) return c.label;
    }
    return camera;
  }

  bool _recordedAt(DateTime time) => widget.data
      .coverage(_camera)
      .any((c) => !time.isBefore(c.start) && time.isBefore(c.end));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final labels = {for (final c in widget.cameras) c.name: c.label};
    final now = _now();
    final playing = _player.playing || _live;
    final export = widget.export;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 16:9 across the width, but in landscape that would push the
          // controls off the screen: the video keeps part of the height.
          SizedBox(
            height: min(
              constraints.maxWidth * 9 / 16,
              constraints.maxHeight * TimelineLayout.maxVideoShare,
            ),
            child: _video(l, locale, labels),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _cameraRow(l, labels, text),
                Row(
                  children: [
                    IconButton(
                      tooltip: l.timelinePreviousDay,
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _shiftDay(-1),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.loadHistory == null
                            ? null
                            : _openCalendar,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: DateFormat.MMMEd(locale)
                                    .format(_playhead),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' · ${DateFormat.Hms(locale).format(_playhead)}',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (widget.loadHistory != null)
                      IconButton(
                        tooltip: l.timelineCalendar,
                        icon: const Icon(Icons.calendar_month_rounded),
                        onPressed: _openCalendar,
                      ),
                    IconButton(
                      tooltip: l.timelineNextDay,
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: shiftDay(_playhead, 1).isAfter(now)
                          ? null
                          : () => _shiftDay(1),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _Transport(
                      icon: Icons.skip_previous_rounded,
                      label: _onReviews
                          ? l.timelinePreviousReview
                          : l.timelinePreviousPassage,
                      onPressed: _seeking
                          ? null
                          : () => _seekPassage(forward: false),
                    ),
                    _Transport(
                      icon: Icons.replay_10_rounded,
                      label: l.timelineSeconds(
                        TimelineScreenDefaults.jump.inSeconds,
                      ),
                      tooltip: l.timelineBack(
                        TimelineScreenDefaults.jump.inSeconds,
                      ),
                      onPressed: () => _goTo(
                        _playhead.subtract(TimelineScreenDefaults.jump),
                      ),
                    ),
                    IconButton.filled(
                      iconSize: 34,
                      tooltip: playing ? l.timelinePause : l.timelinePlay,
                      onPressed: _togglePlay,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    _Transport(
                      icon: Icons.forward_10_rounded,
                      label: l.timelineSeconds(
                        TimelineScreenDefaults.jump.inSeconds,
                      ),
                      tooltip: l.timelineForward(
                        TimelineScreenDefaults.jump.inSeconds,
                      ),
                      onPressed: _live
                          ? null
                          : () => _goTo(
                              _playhead.add(TimelineScreenDefaults.jump),
                            ),
                    ),
                    _Transport(
                      icon: Icons.skip_next_rounded,
                      label: _onReviews
                          ? l.timelineNextReview
                          : l.timelineNextPassage,
                      onPressed: _seeking
                          ? null
                          : () => _seekPassage(forward: true),
                    ),
                    if (widget.live != null)
                      _Transport(
                        icon: Icons.sensors_rounded,
                        label: l.timelineLive,
                        tooltip: l.timelineGoLive,
                        color: _live ? AppColors.live : null,
                        onPressed: _live ? null : _goLive,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _bands(l, labels, now, locale),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (var i = 0; i < timelineZooms.length; i++)
                            ChoiceChip(
                              label: Text(
                                timelineZooms[i] == null
                                    ? l.timelineZoomAll
                                    : l.timelineZoomHours(
                                        timelineZooms[i]!.inHours,
                                      ),
                              ),
                              selected: i == _zoom,
                              onSelected: (_) => _setZoom(i),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<double>(
                      tooltip: l.timelineSpeed,
                      initialValue: _player.speed,
                      onSelected: _setSpeed,
                      itemBuilder: (_) => [
                        for (final s in TimelineScreenDefaults.speeds)
                          PopupMenuItem(value: s, child: Text(_speedText(s))),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 18,
                              color: _player.speed == 1
                                  ? AppColors.textDim
                                  : AppColors.accent,
                            ),
                            Text(
                              _speedText(_player.speed),
                              style: text.labelMedium?.copyWith(
                                color: _player.speed == 1
                                    ? AppColors.textDim
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.data.loading)
                      Tooltip(
                        message: l.timelineLoading,
                        child: const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                if (export != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _exportClip(export),
                          icon: const Icon(Icons.movie_creation_outlined),
                          label: Text(l.timelineClip),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _takingPhoto
                              ? null
                              : () => _takePhoto(export),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(l.timelinePhoto),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "×0,5", "×2" in the language of the app.
  String _speedText(double speed) {
    final locale = Localizations.localeOf(context).toString();
    return '×${NumberFormat.decimalPattern(locale).format(speed)}';
  }

  Widget _cameraRow(
    AppLocalizations l,
    Map<String, String> labels,
    TextTheme text,
  ) {
    return Row(
      children: [
        Expanded(child: _cameraMenu(l, labels, text)),
        // An icon only: the previous and next buttons name the mode.
        if (widget.reviews != null)
          IconButton(
            tooltip: l.timelineSeekReviewsHint,
            isSelected: _seekReviews,
            icon: const Icon(Icons.person_search_outlined),
            selectedIcon: const Icon(Icons.person_search_rounded),
            onPressed: () => _setSeekReviews(!_seekReviews),
          ),
        if (widget.cameras.length > 1)
          FilterChip(
            avatar: const Icon(Icons.grid_view_rounded, size: 18),
            label: Text(l.timelineSeekAll),
            tooltip: l.timelineSeekAllHint,
            selected: _seekAll,
            showCheckmark: false,
            onSelected: _setSeekAll,
          ),
      ],
    );
  }

  Widget _cameraMenu(
    AppLocalizations l,
    Map<String, String> labels,
    TextTheme text,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: l.timelineCamera,
        initialValue: _camera,
        onSelected: (c) => _selectCamera(c),
        itemBuilder: (_) => [
          for (final c in widget.cameras)
            PopupMenuItem(value: c.name, child: Text(c.label)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  l.timelinePlaying(labels[_camera] ?? _camera),
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _video(
    AppLocalizations l,
    String locale,
    Map<String, String> labels,
  ) {
    final live = widget.live;
    if (_live && live != null) return _liveView(l, locale, labels, live);
    final status = _player.camera == _camera
        ? _player.status
        : PlayerStatus.opening;
    final String? message = switch (status) {
      PlayerStatus.failed
          when !_recordedAt(_playhead) &&
              widget.data.isLoaded(_camera, _playhead) =>
        l.timelineNoRecording,
      PlayerStatus.failed => l.timelinePlaybackFailed,
      _ when _atEnd => l.timelineEnd,
      _ => null,
    };
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (status == PlayerStatus.ready) _player.buildView(),
          if (status == PlayerStatus.opening)
            const Center(child: CircularProgressIndicator()),
          if (message != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(message, style: const TextStyle(color: Colors.white)),
                  if (status == PlayerStatus.failed)
                    TextButton(
                      onPressed: () => _open(_playhead),
                      child: Text(l.timelineRetry),
                    ),
                ],
              ),
            ),
          Positioned(
            left: 8,
            top: 8,
            child: _Caption(
              DateFormat('dd/MM HH:mm:ss', locale).format(_playhead),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: _Caption(labels[_camera] ?? _camera),
          ),
          if (_player.imagePlayback && status == PlayerStatus.ready)
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _explainImagePlayback(l),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        Text(
                          l.timelineImagePlayback,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _liveView(
    AppLocalizations l,
    String locale,
    Map<String, String> labels,
    LiveSource live,
  ) {
    final camera = widget.cameras.firstWhere((c) => c.name == _camera);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LivePane(camera: camera, source: live),
          Positioned(
            left: 8,
            top: 8,
            child: _Caption(
              DateFormat('dd/MM HH:mm:ss', locale).format(_playhead),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: _Caption(labels[_camera] ?? _camera),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.live,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.timelineLiveBadge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Why the recording is shown as images, and a way to try the video again.
  Future<void> _explainImagePlayback(AppLocalizations l) async {
    final error = _player.videoError;
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.timelineImagePlaybackTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(l.timelineImagePlaybackBody),
            if (error != null && error.isNotEmpty)
              SelectableText(
                l.timelineImagePlaybackDetail(error),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textDim,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.timelineRetryVideo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.ok),
          ),
        ],
      ),
    );
    if (retry == true && mounted) await _player.retryVideo();
  }

  Widget _bands(
    AppLocalizations l,
    Map<String, String> labels,
    DateTime now,
    String locale,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TimelineBands(
          data: widget.data,
          camera: _camera,
          labels: labels,
          allLabel: l.timelineAllCameras,
          playhead: _playhead,
          span: _span,
          now: now,
          onScrubStart: _onScrubStart,
          onScrub: _onScrub,
          onScrubEnd: _onScrubEnd,
          onPassage: _jumpTo,
          onTime: (t) => _goTo(t),
        ),
        // Fixed playhead in the middle.
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 2,
                height: TimelineBands.height - TimelineBands.ticksHeight,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;

  /// Colour of a button that shows a state (the live on); dimmed when
  /// disabled otherwise.
  final Color? color;

  const _Transport({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? (onPressed == null ? AppColors.textDim : null);
    return Expanded(
      child: Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
