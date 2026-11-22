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

  HlsRecordingPlayer(this._proxy);

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
  bool get completed => _controller?.value.isCompleted ?? false;

  @override
  Future<void> open(String camera, DateTime start, DateTime end) async {
    final generation = ++_generation;
    await _release();
    _camera = camera;
    _start = start;
    _end = end;
    _status = PlayerStatus.opening;
    notifyListeners();
    try {
      await _proxy.start();
      final controller = VideoPlayerController.networkUrl(
        _proxy.playlist(camera, start, end),
        formatHint: VideoFormat.hls,
      );
      _controller = controller;
      await controller.initialize();
      if (generation != _generation) return;
      controller.addListener(_onController);
      _status = PlayerStatus.ready;
    } catch (_) {
      if (generation != _generation) return;
      _status = PlayerStatus.failed;
    }
    notifyListeners();
  }

  void _onController() {
    if (_controller?.value.hasError ?? false) _status = PlayerStatus.failed;
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
