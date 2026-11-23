import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../core/frigate/vod_proxy.dart';

enum PlayerStatus { idle, opening, ready, failed }

/// Plays a camera's recordings from a given time; injected so the timeline
/// can be tested without a video decoder.
abstract class RecordingPlayer extends ChangeNotifier {
  PlayerStatus get status;

  /// Camera and time range opened last.
  String? get camera;
  DateTime? get start;
  DateTime? get end;

  /// Time of the frame shown, or `null` before opening.
  DateTime? get time;

  bool get playing;

  /// True at the end of the range opened.
  bool get completed;

  /// Opens the recordings of [camera] from [start] to [end]; the first frame
  /// is shown, paused.
  Future<void> open(String camera, DateTime start, DateTime end);

  Future<void> play();
  Future<void> pause();

  /// Moves to [time] inside the range opened.
  Future<void> seek(DateTime time);

  Widget buildView();

  /// True when recorded images are shown instead of the video.
  bool get imagePlayback => false;

  /// Why the video could not be played, as reported by the decoder.
  String? get videoError => null;

  /// Tries the video again after a fallback to images.
  Future<void> retryVideo() async {}

  /// Playback speed, 1 for real time; kept across [open].
  double get speed => 1;
  Future<void> setSpeed(double speed) async {}
}

/// [RecordingPlayer] reading Frigate's HLS recordings through [VodProxy].
class HlsRecordingPlayer extends RecordingPlayer {
  final VodProxy _proxy;
  VideoPlayerController? _controller;
  PlayerStatus _status = PlayerStatus.idle;
  String? _camera;
  DateTime? _start;
  DateTime? _end;
  int _generation = 0;
  String? _error;
  double _speed = 1;

  HlsRecordingPlayer(this._proxy);

  @override
  double get speed => _speed;

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.setPlaybackSpeed(speed);
    }
    notifyListeners();
  }

  @override
  PlayerStatus get status => _status;
  @override
  String? get camera => _camera;
  @override
  DateTime? get start => _start;
  @override
  DateTime? get end => _end;

  @override
  DateTime? get time {
    final start = _start;
    final controller = _controller;
    if (start == null) return null;
    if (controller == null || !controller.value.isInitialized) return start;
    return start.add(controller.value.position);
  }

  @override
  bool get playing => _controller?.value.isPlaying ?? false;

  @override
  String? get videoError => _error;

  @override
  bool get completed => _controller?.value.isCompleted ?? false;

  @override
  Future<void> open(String camera, DateTime start, DateTime end) async {
    final generation = ++_generation;
    await _release();
    // A newer open (or dispose) came while the previous video was released.
    if (generation != _generation) return;
    _camera = camera;
    _start = start;
    _end = end;
    _error = null;
    _status = PlayerStatus.opening;
    notifyListeners();
    VideoPlayerController? controller;
    try {
      await _proxy.start();
      if (generation != _generation) return;
      controller = VideoPlayerController.networkUrl(
        _proxy.playlist(camera, start, end),
        formatHint: VideoFormat.hls,
      );
      await controller.initialize();
      if (_speed != 1 && generation == _generation) {
        await controller.setPlaybackSpeed(_speed);
      }
      if (generation != _generation) {
        // Outdated: its decoder must not stay allocated.
        await _discard(controller);
        return;
      }
      _controller = controller;
      controller.addListener(_onController);
      _status = PlayerStatus.ready;
    } catch (e) {
      await _discard(controller);
      if (generation != _generation) return;
      _error = '$e';
      _status = PlayerStatus.failed;
    }
    notifyListeners();
  }

  /// Frees a video that will not be shown.
  static Future<void> _discard(VideoPlayerController? controller) async {
    try {
      await controller?.dispose();
    } catch (_) {
      // Already broken: nothing left to free.
    }
  }

  void _onController() {
    final value = _controller?.value;
    if (value != null && value.hasError) {
      _status = PlayerStatus.failed;
      _error = value.errorDescription ?? _error;
    }
    notifyListeners();
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seek(DateTime time) async {
    final start = _start;
    if (start == null) return;
    await _controller?.seekTo(time.difference(start));
  }

  @override
  Widget buildView() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Future<void> _release() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onController);
    await controller?.dispose();
  }

  @override
  void dispose() {
    _generation++;
    _release();
    super.dispose();
  }
}
