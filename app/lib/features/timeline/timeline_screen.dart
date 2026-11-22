import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_sheet.dart';
import 'motion_passages.dart';
import 'recording_history.dart';
import 'recording_player.dart';
import 'timeline_bands.dart';
import 'timeline_data.dart';

abstract final class TimelineScreenDefaults {
  /// Where the timeline opens: just behind the live edge.
  static const startBehindNow = Duration(minutes: 1);

  /// The newest few seconds are not written to disk yet.
  static const liveMargin = Duration(seconds: 10);

  /// Length of recording opened at once in the player.
  static const window = Duration(hours: 1);

  /// Jump of the back and forward buttons.
  static const jump = Duration(seconds: 10);

  /// Zoom chosen when the screen opens (index in [timelineZooms]).
  static const zoom = 1;

  /// Delay after a drag before the player opens the new time.
  static const settle = Duration(milliseconds: 350);
}

/// Timeline tab (mock-up screen 4): recordings of one camera played under
/// two bands, every camera and the camera played, with a common playhead.
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

  const TimelineScreen({
    super.key,
    required this.cameras,
    required this.data,
    required this.playerFactory,
    this.clock,
    this.loadHistory,
    this.openAt,
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
  Timer? _settle;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  DateTime get _liveEdge => _now().subtract(TimelineScreenDefaults.liveMargin);

  Duration get _span =>
      timelineZooms[_zoom] ??
      historySpan(
        widget.cameras.expand(
          (c) => [c.continuousDays, c.motionDays, c.alertDays],
        ),
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
    _ensure();
    _open(_playhead, play: known);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settle?.cancel();
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

  void _onPlayer() {
    if (!mounted) return;
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
      _atEnd = true;
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
    final shouldPlay = play ?? _player.playing;
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
    _open(at ?? _playhead, play: _player.playing || at != null);
  }

  Future<void> _seekPassage({required bool forward}) async {
    if (_seeking) return;
    setState(() => _seeking = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final passage = await widget.data.seekPassage(_playhead, forward: forward);
    if (!mounted) return;
    setState(() => _seeking = false);
    if (passage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.timelineNoPassage(TimelineDefaults.seekLimit.inHours),
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
    _resumeAfterScrub = _player.playing || _resumeAfterScrub;
    _scrubbing = true;
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
      _goTo(_playhead, play: play);
    });
  }

  void _shiftDay(int days) =>
      _goTo(_playhead.add(Duration(days: days)), play: false);

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
    final playing = _player.playing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: _video(l, locale, labels)),
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
                      onTap: widget.loadHistory == null ? null : _openCalendar,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: DateFormat.MMMEd(locale).format(_playhead),
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
                    onPressed:
                        _playhead.add(const Duration(days: 1)).isAfter(now)
                        ? null
                        : () => _shiftDay(1),
                  ),
                ],
              ),
              Row(
                children: [
                  _Transport(
                    icon: Icons.skip_previous_rounded,
                    label: l.timelinePreviousPassage,
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
                    onPressed: () =>
                        _goTo(_playhead.subtract(TimelineScreenDefaults.jump)),
                  ),
                  IconButton.filled(
                    iconSize: 34,
                    tooltip: playing ? l.timelinePause : l.timelinePlay,
                    onPressed: _togglePlay,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                    onPressed: () =>
                        _goTo(_playhead.add(TimelineScreenDefaults.jump)),
                  ),
                  _Transport(
                    icon: Icons.skip_next_rounded,
                    label: l.timelineNextPassage,
                    onPressed: _seeking
                        ? null
                        : () => _seekPassage(forward: true),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraRow(
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
              Text(
                l.timelinePlaying(labels[_camera] ?? _camera),
                style: text.titleSmall,
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
        ],
      ),
    );
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

  const _Transport({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? AppColors.textDim : null;
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
