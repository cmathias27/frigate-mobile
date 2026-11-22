import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import 'camera_feed.dart';
import 'feed_tile.dart';

/// One camera in full screen (mock-up screen 3): full-resolution frames
/// refreshed every second, pinch to zoom, swipe to the next camera, tap to
/// hide the bars.
///
/// WebRTC video, sound and "Talk" come in a following version; their
/// buttons will only appear on cameras whose capabilities allow them.
class CameraFullScreen extends StatefulWidget {
  final List<CameraCapabilities> cameras;
  final String initialCamera;
  final ImageFetcher fetch;
  final VoidCallback? onAuthError;

  const CameraFullScreen({
    super.key,
    required this.cameras,
    required this.initialCamera,
    required this.fetch,
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
  bool _immersive = false;

  CameraCapabilities get _camera => widget.cameras[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.cameras.indexWhere((c) => c.name == widget.initialCamera);
    if (_index < 0) _index = 0;
    _pageController = PageController(initialPage: _index);
    _startFeed();
  }

  void _startFeed() {
    _feed?.dispose();
    _feed = CameraFeed(
      camera: _camera.name,
      fetch: widget.fetch,
      interval: LiveDefaults.fullScreenInterval,
      onAuthError: widget.onAuthError,
    )..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _feed?.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _feed?.stop();
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
    _feed?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final feed = _feed!;
    final seconds = LiveDefaults.fullScreenInterval.inSeconds;

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
                    l.liveModeSnapshots(seconds),
                    style: text.bodySmall?.copyWith(color: AppColors.textDim),
                  ),
                ],
              ),
              actions: [
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
          setState(() => _index = i);
          _startFeed();
        },
        itemBuilder: (context, i) {
          if (i != _index) {
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
                    child: FeedImage(feed: feed, fit: BoxFit.contain),
                  ),
                  if (!_immersive)
                    Positioned(
                      left: 12,
                      bottom: 16 + MediaQuery.paddingOf(context).bottom,
                      child: Row(
                        spacing: 8,
                        children: [
                          LiveBadge(stale: feed.isStale),
                          if (feed.updatedAt != null)
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
