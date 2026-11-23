import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import 'camera_feed.dart';
import 'feed_tile.dart';
import 'live_video.dart';
import 'photo.dart';

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
  final PhotoActions photoActions;
  final VoidCallback? onAuthError;

  /// Opens each camera on its lightest stream rather than the main one.
  final bool lightStreamFirst;

  /// A failed stream hands over to the camera's next one.
  final bool tryOtherStreams;

  const CameraFullScreen({
    super.key,
    required this.cameras,
    required this.initialCamera,
    required this.fetch,
    this.videoFactory,
    this.photoActions = const DevicePhotoActions(),
    this.onAuthError,
    this.lightStreamFirst = false,
    this.tryOtherStreams = LiveVideoDefaults.tryOtherStreams,
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
  bool _takingPhoto = false;

  /// Chosen go2rtc stream per camera, by index in its live streams.
  final _streamIndex = <String, int>{};

  /// Streams of the current camera that failed since it was opened, so the
  /// automatic switch tries each one once.
  final _failedStreams = <int>{};

  CameraCapabilities get _camera => widget.cameras[_index];

  int get _currentStream =>
      _streamIndex[_camera.name] ??
      (widget.lightStreamFirst ? _camera.liveStreams.length - 1 : 0);

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
    _failedStreams.clear();
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
    final video = _video;
    if (video?.status == LiveVideoStatus.failed) {
      _failedStreams.add(_currentStream);
      final next = _nextStream();
      if (next != null) {
        // Not from inside the failed video's own notification.
        Future.microtask(() {
          if (mounted && identical(_video, video)) _switchStream(next);
        });
      }
    }
    if (_videoPlaying) {
      _feed?.stop();
    } else {
      _feed?.start();
    }
    setState(() {});
  }

  /// The next stream of the camera not failed yet, when the automatic
  /// switch is on.
  int? _nextStream() {
    if (!widget.tryOtherStreams) return null;
    final count = _camera.liveStreams.length;
    for (var step = 1; step < count; step++) {
      final index = (_currentStream + step) % count;
      if (!_failedStreams.contains(index)) return index;
    }
    return null;
  }

  void _switchStream(int index) {
    setState(() {
      _streamIndex[_camera.name] = index;
      _closeVideo();
      _feed?.start();
      _openVideo();
    });
  }

  void _retryVideo() {
    setState(() {
      _failedStreams.clear();
      _closeVideo();
      _openVideo();
    });
  }

  void _selectStream(int index) {
    _failedStreams.clear();
    _switchStream(index);
  }

  /// Saves the picture on screen: the video frame at the stream's
  /// resolution when the video plays, otherwise Frigate's latest image.
  Future<void> _takePhoto() async {
    if (_takingPhoto) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final camera = _camera.name;
    setState(() => _takingPhoto = true);
    try {
      final jpeg = await _video?.captureFrame() ?? await widget.fetch(camera);
      final name = photoName(camera, DateTime.now());
      await widget.photoActions.save(jpeg, name);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.livePhotoSaved(DevicePhotoActions.album)),
          action: SnackBarAction(
            label: l.livePhotoShare,
            onPressed: () => widget.photoActions.share(jpeg, name),
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
                      right: 12,
                      bottom: 12 + MediaQuery.paddingOf(context).bottom,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          Row(
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
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          _Controls(
                            children: [
                              _ControlButton(
                                icon: Icons.photo_camera_outlined,
                                label: l.livePhoto,
                                busy: _takingPhoto,
                                onPressed: feed.image != null || _videoPlaying
                                    ? _takePhoto
                                    : null,
                              ),
                              // Sound only when the stream carries some.
                              if (_videoPlaying && video!.hasAudio)
                                _ControlButton(
                                  icon: video.muted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  label: l.liveSound,
                                  tooltip: video.muted
                                      ? l.liveSoundOn
                                      : l.liveSoundOff,
                                  active: !video.muted,
                                  onPressed: () => video.muted = !video.muted,
                                ),
                            ],
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

/// Row of buttons under the picture (mock-up screen 3).
class _Controls extends StatelessWidget {
  final List<Widget> children;

  const _Controls({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [for (final c in children) Expanded(child: c)],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool active;
  final bool busy;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.tooltip,
    this.active = false,
    this.busy = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final color = active
        ? AppColors.accent
        : enabled
        ? Colors.white
        : AppColors.textDim;
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: color),
                Text(label, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
