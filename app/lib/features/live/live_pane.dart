import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/frigate/capabilities.dart';
import 'camera_feed.dart';
import 'feed_tile.dart';
import 'live_video.dart';

/// Where another screen (the timeline) reads a camera live.
class LiveSource {
  final ImageFetcher fetch;

  /// Live video; images only without it.
  final LiveVideoFactory? videoFactory;
  final VoidCallback? onAuthError;

  /// Starts on the camera's lightest stream.
  final bool lightStreamFirst;

  /// A failed stream hands over to the camera's next one.
  final bool tryOtherStreams;

  const LiveSource({
    required this.fetch,
    this.videoFactory,
    this.onAuthError,
    this.lightStreamFirst = LivePaneDefaults.lightStreamFirst,
    this.tryOtherStreams = LiveVideoDefaults.tryOtherStreams,
  });
}

abstract final class LivePaneDefaults {
  /// A small pane starts on the camera's lightest stream (its last one,
  /// often the sub-stream), which every phone decodes, rather than the main
  /// quality.
  static const lightStreamFirst = true;
}

/// One camera live in a box: images at once, the video over them from its
/// first frame, the camera's other streams tried when a stream fails.
/// Nothing is read while the app is in the background.
class LivePane extends StatefulWidget {
  final CameraCapabilities camera;
  final LiveSource source;
  final BoxFit fit;

  const LivePane({
    super.key,
    required this.camera,
    required this.source,
    this.fit = BoxFit.contain,
  });

  @override
  State<LivePane> createState() => _LivePaneState();
}

class _LivePaneState extends State<LivePane> with WidgetsBindingObserver {
  CameraFeed? _feed;
  LiveVideo? _video;
  int _stream = 0;
  final _failed = <int>{};

  List<String> get _streams => widget.camera.liveStreams;
  bool get _playing => _video?.status == LiveVideoStatus.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didUpdateWidget(LivePane old) {
    super.didUpdateWidget(old);
    if (old.camera.name != widget.camera.name) _open();
  }

  void _open() {
    _close();
    _failed.clear();
    _stream = widget.source.lightStreamFirst && _streams.isNotEmpty
        ? _streams.length - 1
        : 0;
    _feed = CameraFeed(
      camera: widget.camera.name,
      fetch: widget.source.fetch,
      interval: LiveDefaults.fullScreenInterval,
      onAuthError: widget.source.onAuthError,
    )..start();
    _openVideo();
  }

  void _openVideo() {
    final factory = widget.source.videoFactory;
    if (factory == null || _streams.isEmpty) return;
    final video = factory(_streams[_stream])..addListener(_onVideo);
    _video = video;
    unawaited(video.start());
  }

  void _closeVideo() {
    _video
      ?..removeListener(_onVideo)
      ..dispose();
    _video = null;
  }

  void _close() {
    _closeVideo();
    _feed?.dispose();
    _feed = null;
  }

  void _onVideo() {
    if (!mounted) return;
    final video = _video;
    if (video?.status == LiveVideoStatus.failed) {
      _failed.add(_stream);
      final next = _nextStream();
      if (next != null) {
        // Not from inside the failed video's own notification.
        Future.microtask(() {
          if (!mounted || !identical(_video, video)) return;
          setState(() {
            _stream = next;
            _closeVideo();
            _openVideo();
          });
        });
      }
    }
    if (_playing) {
      _feed?.stop();
    } else {
      _feed?.start();
    }
    setState(() {});
  }

  int? _nextStream() {
    if (!widget.source.tryOtherStreams) return null;
    final count = _streams.length;
    for (var step = 1; step < count; step++) {
      final index = (_stream + step) % count;
      if (!_failed.contains(index)) return index;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_feed == null) setState(_open);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_feed != null) setState(_close);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final video = _video;
    if (feed == null) return const ColoredBox(color: Colors.black);
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (video != null && video.status != LiveVideoStatus.failed)
            video.buildView(widget.fit),
          if (!_playing)
            ColoredBox(
              color: Colors.black,
              child: FeedImage(feed: feed, fit: widget.fit),
            ),
        ],
      ),
    );
  }
}
