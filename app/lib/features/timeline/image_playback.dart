import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'recording_player.dart';

/// Reads the recorded frame of a camera at a time, scaled to [height].
typedef RecordedFrameFetcher = Future<Uint8List> Function(
  String camera,
  DateTime time, {
  int? height,
});

/// Default playback settings (decision 0002: a default value now, an
/// optional setting later).
abstract final class ImagePlaybackDefaults {
  /// A video that cannot be decoded by the phone (too large for its decoder,
  /// for instance) is played back as recorded images instead.
  static const fallbackToImages = true;

  /// A video playing whose time does not move for this long is frozen.
  static const frozenAfter = Duration(seconds: 10);

  /// How often a playing video is checked.
  static const frameCheck = Duration(seconds: 2);

  /// Most images asked per second; Frigate takes about 0.2 s to cut one.
  static const maxRate = 4;

  /// Height of the images asked to Frigate.
  static const height = 720;
}

/// [RecordingPlayer] showing the recorded frames one after another, in real
/// time, as fast as Frigate cuts them: it works whatever the phone's video
/// decoder can do.
class ImageRecordingPlayer extends RecordingPlayer {
  final RecordedFrameFetcher _fetch;
  final DateTime Function() _clock;
  final int height;
  final int maxRate;

  PlayerStatus _status = PlayerStatus.idle;
  String? _camera;
  DateTime? _start;
  DateTime? _end;

  /// Recording time shown when paused, or when playing started.
  DateTime? _base;

  /// Wall time when playing started, `null` when paused.
  DateTime? _playingSince;
  bool _completed = false;
  Uint8List? _image;
  Timer? _timer;
  bool _fetching = false;
  int _generation = 0;
  bool _disposed = false;
  double _speed = 1;

  ImageRecordingPlayer(
    this._fetch, {
    DateTime Function()? clock,
    this.height = ImagePlaybackDefaults.height,
    this.maxRate = ImagePlaybackDefaults.maxRate,
  }) : _clock = clock ?? DateTime.now;

  @override
  bool get imagePlayback => true;
  @override
  double get speed => _speed;
  @override
  PlayerStatus get status => _status;
  @override
  String? get camera => _camera;
  @override
  DateTime? get start => _start;
  @override
  DateTime? get end => _end;
  @override
  bool get playing => _playingSince != null;
  @override
  bool get completed => _completed;

  @override
  DateTime? get time {
    final base = _base;
    final since = _playingSince;
    if (base == null || since == null) return base;
    final t = base.add(_clock().difference(since) * _speed);
    final end = _end;
    return end != null && t.isAfter(end) ? end : t;
  }

  @override
  Future<void> open(String camera, DateTime start, DateTime end) async {
    final generation = ++_generation;
    _stopTimer();
    _camera = camera;
    _start = start;
    _end = end;
    _base = start;
    _playingSince = null;
    _completed = false;
    _image = null;
    _status = PlayerStatus.opening;
    _notify();
    try {
      final image = await _fetch(camera, start, height: height);
      if (generation != _generation) return;
      _image = image;
      _status = PlayerStatus.ready;
    } catch (_) {
      if (generation != _generation) return;
      _status = PlayerStatus.failed;
    }
    _notify();
  }

  @override
  Future<void> play() async {
    if (_status != PlayerStatus.ready || playing) return;
    if (_completed) {
      _base = _start;
      _completed = false;
    }
    _playingSince = _clock();
    _timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ maxRate),
      (_) => _tick(),
    );
    _notify();
  }

  @override
  Future<void> setSpeed(double speed) async {
    // The time reached so far stays; the new speed counts from now.
    if (playing) {
      _base = time;
      _playingSince = _clock();
    }
    _speed = speed;
    _notify();
  }

  @override
  Future<void> pause() async {
    if (!playing) return;
    _base = time;
    _playingSince = null;
    _stopTimer();
    _notify();
  }

  @override
  Future<void> seek(DateTime time) async {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return;
    var t = time.isBefore(start) ? start : time;
    if (t.isAfter(end)) t = end;
    _base = t;
    _completed = false;
    if (playing) _playingSince = _clock();
    _notify();
    await _show(t);
  }

  void _tick() {
    final t = time;
    final end = _end;
    if (t == null || end == null) return;
    if (!t.isBefore(end)) {
      _base = end;
      _playingSince = null;
      _completed = true;
      _stopTimer();
      _notify();
      return;
    }
    // The playhead moves on every tick, the image when Frigate sent it.
    _notify();
    if (!_fetching) unawaited(_show(t));
  }

  Future<void> _show(DateTime t) async {
    final camera = _camera;
    if (camera == null) return;
    final generation = _generation;
    _fetching = true;
    try {
      final image = await _fetch(camera, t, height: height);
      if (generation != _generation || _disposed) return;
      _image = image;
      _notify();
    } catch (_) {
      // A missing frame keeps the previous one; the next tick asks again.
    } finally {
      if (generation == _generation) _fetching = false;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Widget buildView() {
    final image = _image;
    if (image == null || image.isEmpty) return const SizedBox.expand();
    return Image.memory(
      image,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _stopTimer();
    super.dispose();
  }
}

/// Plays the video and, when it fails or freezes on a camera, the recorded
/// images of that camera for the rest of the session.
class FallbackRecordingPlayer extends RecordingPlayer {
  final RecordingPlayer video;
  final RecordingPlayer images;
  final bool enabled;
  final Duration frozenAfter;
  final Duration frameCheck;
  final DateTime Function() _clock;

  /// Cameras whose video could not be played.
  final _imageCameras = <String>{};
  late RecordingPlayer _active = video;

  /// [play] was asked and not paused since: used to tell a frozen video
  /// from a paused one.
  bool _wantPlaying = false;
  Timer? _watch;
  DateTime? _lastTime;
  DateTime? _lastMove;
  bool _switching = false;

  /// The images were tried for the video opened last.
  bool _triedImages = false;

  /// Why the video failed last, as reported by the player.
  String? _videoError;

  FallbackRecordingPlayer({
    required this.video,
    required this.images,
    this.enabled = ImagePlaybackDefaults.fallbackToImages,
    this.frozenAfter = ImagePlaybackDefaults.frozenAfter,
    this.frameCheck = ImagePlaybackDefaults.frameCheck,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    video.addListener(_onVideo);
    images.addListener(_onImages);
  }

  @override
  bool get imagePlayback => identical(_active, images);
  @override
  String? get videoError => _videoError ?? video.videoError;
  @override
  double get speed => _active.speed;

  @override
  Future<void> setSpeed(double speed) async {
    // Both keep it, so a switch to images keeps the speed chosen.
    await video.setSpeed(speed);
    await images.setSpeed(speed);
  }

  @override
  PlayerStatus get status => _switching ? PlayerStatus.opening : _active.status;
  @override
  String? get camera => _active.camera;
  @override
  DateTime? get start => _active.start;
  @override
  DateTime? get end => _active.end;
  @override
  DateTime? get time => _active.time;
  @override
  bool get playing => _active.playing;
  @override
  bool get completed => _active.completed;

  @override
  Future<void> open(String camera, DateTime start, DateTime end) async {
    _wantPlaying = false;
    _triedImages = false;
    _stopWatch();
    if (enabled && _imageCameras.contains(camera)) {
      if (identical(_active, video)) await video.pause();
      _active = images;
    } else {
      if (identical(_active, images)) await images.pause();
      _active = video;
    }
    await _active.open(camera, start, end);
  }

  @override
  Future<void> play() async {
    _wantPlaying = true;
    await _active.play();
    if (identical(_active, video)) _startWatch();
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    _stopWatch();
    await _active.pause();
  }

  @override
  Future<void> seek(DateTime time) async {
    _lastMove = _clock();
    await _active.seek(time);
  }

  @override
  Widget buildView() => _active.buildView();

  void _onVideo() {
    if (identical(_active, video)) {
      if (video.completed) _stopWatch();
      if (video.status == PlayerStatus.failed) unawaited(_toImages());
      notifyListeners();
    }
  }

  void _onImages() {
    if (identical(_active, images)) notifyListeners();
  }

  void _startWatch() {
    _stopWatch();
    _lastTime = video.time;
    _lastMove = _clock();
    _watch = Timer.periodic(frameCheck, (_) => _check());
  }

  void _stopWatch() {
    _watch?.cancel();
    _watch = null;
  }

  void _check() {
    if (!identical(_active, video) || !_wantPlaying || video.completed) {
      return _stopWatch();
    }
    final t = video.time;
    final now = _clock();
    if (t != _lastTime) {
      _lastTime = t;
      _lastMove = now;
    } else if (now.difference(_lastMove ?? now) >= frozenAfter) {
      _videoError ??= 'frozen';
      unawaited(_toImages());
    }
  }

  /// The video of this camera cannot be played: its recorded images take
  /// over at the same time.
  Future<void> _toImages() async {
    final camera = video.camera;
    final start = video.start;
    final end = video.end;
    if (!enabled || _switching || _triedImages || camera == null) return;
    if (start == null || end == null) return;
    final at = video.time ?? start;
    final play = _wantPlaying;
    _triedImages = true;
    _switching = true;
    _stopWatch();
    _videoError = video.videoError ?? _videoError;
    _active = images;
    notifyListeners();
    try {
      await video.pause();
    } catch (_) {
      // A failed video may refuse even to pause.
    }
    await images.open(camera, start, end);
    _switching = false;
    if (images.status != PlayerStatus.ready) {
      // No image either (no recording there, server unreachable): not the
      // phone's fault, the video keeps the camera and shows its failure.
      _active = video;
      notifyListeners();
      return;
    }
    _imageCameras.add(camera);
    if (at.isAfter(start)) await images.seek(at);
    if (play) await images.play();
    notifyListeners();
  }

  @override
  Future<void> retryVideo() async {
    final camera = _active.camera;
    final start = _active.start;
    final end = _active.end;
    if (camera == null || start == null || end == null) return;
    final at = _active.time ?? start;
    final play = _wantPlaying;
    _imageCameras.remove(camera);
    _videoError = null;
    await open(camera, start, end);
    if (at.isAfter(start)) await seek(at);
    if (play) await this.play();
  }

  @override
  void dispose() {
    _stopWatch();
    video.removeListener(_onVideo);
    images.removeListener(_onImages);
    video.dispose();
    images.dispose();
    super.dispose();
  }
}
