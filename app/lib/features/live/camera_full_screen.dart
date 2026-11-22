import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import 'camera_feed.dart';
import 'feed_tile.dart';
import 'live_video.dart';

/// One camera in full screen (mock-up screen 3): live video when
/// [videoFactory] is given and the server answers, otherwise full-resolution
/// images every second. Pinch to zoom, swipe to the next camera, tap to hide
/// the bars.
///
/// Images show at once and keep refreshing until the first video frame, and
/// again if the video drops, so the screen is never empty.
class CameraFullScreen extends StatefulWidget {
  final List<CameraCapabilities> cameras;
  final String initialCamera;
  final ImageFetcher fetch;
  final LiveVideoFactory? videoFactory;
  final VoidCallback? onAuthError;

  const CameraFullScreen({
    super.key,
    required this.cameras,
    required this.initialCamera,
    required this.fetch,
    this.videoFactory,
    this.onAuthError,
  });

  @override
  State<CameraFullScreen> createState() => _CameraFullScreenState();
}

class _CameraFullScreenState extends State<CameraFullScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late int _index;
  CameraFeed? _feed;
  LiveVideo? _video;
  bool _immersive = false;

  /// Chosen go2rtc stream per camera, by index in its live streams.
  final _streamIndex = <String, int>{};

  CameraCapabilities get _camera => widget.cameras[_index];

  int get _currentStream => _streamIndex[_camera.name] ?? 0;

  bool get _videoPlaying => _video?.status == LiveVideoStatus.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.cameras.indexWhere((c) => c.name == widget.initialCamera);
    if (_index < 0) _index = 0;
    _pageController = PageController(initialPage: _index);
    _open();
  }

  /// (Re)opens images and video for the current camera.
  void _open() {
    _close();
    _feed = CameraFeed(
      camera: _camera.name,
      fetch: widget.fetch,
      interval: LiveDefaults.fullScreenInterval,
      onAuthError: widget.onAuthError,
    )..start();
    _openVideo();
  }

  void _openVideo() {
    final factory = widget.videoFactory;
    final streams = _camera.liveStreams;
    if (factory == null || streams.isEmpty) return;
    final stream = streams[_currentStream.clamp(0, streams.length - 1)];
    final video = factory(stream)..addListener(_onVideoChanged);
    _video = video;
    video.start();
  }

  void _closeVideo() {
    _video
      ?..removeListener(_onVideoChanged)
      ..dispose();
    _video = null;
  }

  void _close() {
    _closeVideo();
    _feed?.dispose();
    _feed = null;
  }

  /// Images are only needed while the video is not playing.
  void _onVideoChanged() {
    if (!mounted) return;
    if (_videoPlaying) {
      _feed?.stop();
    } else {
      _feed?.start();
    }
    setState(() {});
  }

  void _retryVideo() {
    setState(() {
      _closeVideo();
      _openVideo();
    });
  }

  void _selectStream(int index) {
    setState(() {
      _streamIndex[_camera.name] = index;
      _closeVideo();
      _feed?.start();
      _openVideo();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No traffic and no open connection while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      if (_feed == null) setState(_open);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_feed != null) setState(_close);
    }
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _close();
    _pageController.dispose();
    super.dispose();
  }

  String _subtitle(AppLocalizations l) {
    final video = _video;
    final streams = _camera.liveStreams.length;
    if (video != null && video.status != LiveVideoStatus.failed) {
      final quality = streams > 1
          ? ' · ${l.liveStream(_currentStream + 1)}'
          : '';
      return video.status == LiveVideoStatus.playing
          ? '${l.liveModeVideo}$quality'
          : l.liveVideoConnecting;
    }
    final images = l.liveModeSnapshots(
      LiveDefaults.fullScreenInterval.inSeconds,
    );
    return video == null ? images : '${l.liveVideoUnavailable} · $images';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final video = _video;
    final streams = _camera.liveStreams;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _immersive
          ? null
          : AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              centerTitle: true,
              title: Column(
                children: [
                  Text(
                    _camera.label,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _subtitle(l),
                    style: text.bodySmall?.copyWith(color: AppColors.textDim),
                  ),
                ],
              ),
              actions: [
                if (video?.status == LiveVideoStatus.failed)
                  IconButton(
                    tooltip: l.liveVideoRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _retryVideo,
                  ),
                if (_videoPlaying && video!.hasAudio)
                  IconButton(
                    tooltip: video.muted ? l.liveSoundOn : l.liveSoundOff,
                    icon: Icon(
                      video.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                    onPressed: () => video.muted = !video.muted,
                  ),
                if (video != null && streams.length > 1)
                  PopupMenuButton<int>(
                    tooltip: l.liveQuality,
                    icon: const Icon(Icons.hd_outlined),
                    initialValue: _currentStream,
                    onSelected: _selectStream,
                    itemBuilder: (context) => [
                      for (var i = 0; i < streams.length; i++)
                        PopupMenuItem(
                          value: i,
                          child: Text(
                            i == 0
                                ? l.liveStreamMain(i + 1)
                                : l.liveStream(i + 1),
                          ),
                        ),
                    ],
                  ),
                IconButton(
                  tooltip: l.liveFullScreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: _toggleImmersive,
                ),
              ],
            ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.cameras.length,
        onPageChanged: (i) {
          setState(() {
            _index = i;
            _open();
          });
        },
        itemBuilder: (context, i) {
          final feed = _feed;
          if (i != _index || feed == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleImmersive,
            child: ListenableBuilder(
              listenable: feed,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    maxScale: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The video renders underneath from the start, the
                        // images cover it until its first frame.
                        if (video != null &&
                            video.status != LiveVideoStatus.failed)
                          video.buildView(BoxFit.contain),
                        if (!_videoPlaying)
                          ColoredBox(
                            color: Colors.black,
                            child: FeedImage(feed: feed, fit: BoxFit.contain),
                          ),
                      ],
                    ),
                  ),
                  if (!_immersive)
                    Positioned(
                      left: 12,
                      bottom: 16 + MediaQuery.paddingOf(context).bottom,
                      child: Row(
                        spacing: 8,
                        children: [
                          LiveBadge(stale: !_videoPlaying && feed.isStale),
                          if (!_videoPlaying && feed.updatedAt != null)
                            Text(
                              DateFormat.yMd(
                                Localizations.localeOf(context).toString(),
                              ).add_Hms().format(feed.updatedAt!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
