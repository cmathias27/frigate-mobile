import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import 'camera_feed.dart';
import 'camera_full_screen.dart';
import 'feed_tile.dart';
import 'live_video.dart';

/// Grid layouts offered in the app bar: 1, 4 or 9 cameras per page.
const liveLayouts = [1, 4, 9];

/// "Direct" tab (mock-up screen 2): every camera in pages of 1, 4 or 9
/// thumbnails, refreshed while visible; a tap opens the full screen.
class LiveGridScreen extends StatefulWidget {
  final List<CameraCapabilities> cameras;
  final ImageFetcher fetch;
  final LiveVideoFactory? videoFactory;
  final int layout;
  final VoidCallback? onAuthError;

  const LiveGridScreen({
    super.key,
    required this.cameras,
    required this.fetch,
    this.videoFactory,
    this.layout = 4,
    this.onAuthError,
  });

  @override
  State<LiveGridScreen> createState() => _LiveGridScreenState();
}

class _LiveGridScreenState extends State<LiveGridScreen>
    with WidgetsBindingObserver {
  final _feeds = <String, CameraFeed>{};
  final _pageController = PageController();
  int _page = 0;
  bool _paused = false;

  int get _pageCount =>
      math.max(1, (widget.cameras.length / widget.layout).ceil());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncFeeds();
  }

  @override
  void didUpdateWidget(LiveGridScreen old) {
    super.didUpdateWidget(old);
    if (old.layout != widget.layout) {
      // Keep the first camera of the current page in view.
      final first = _page * old.layout;
      _page = math.min(first ~/ widget.layout, _pageCount - 1);
      if (_pageController.hasClients) _pageController.jumpToPage(_page);
    }
    if (old.fetch != widget.fetch) {
      for (final feed in _feeds.values) {
        feed.dispose();
      }
      _feeds.clear();
    }
    _syncFeeds();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No traffic while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _syncFeeds();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _paused = true;
      _syncFeeds();
    }
  }

  /// Creates a feed per camera and runs only those of the visible page.
  void _syncFeeds() {
    final names = {for (final c in widget.cameras) c.name};
    for (final name in _feeds.keys.toList()) {
      if (!names.contains(name)) {
        _feeds.remove(name)!.dispose();
      }
    }
    final visible = _visibleCameras().map((c) => c.name).toSet();
    final height = LiveDefaults.thumbnailHeight(widget.layout);
    for (final camera in widget.cameras) {
      final feed = _feeds.putIfAbsent(
        camera.name,
        () => CameraFeed(
          camera: camera.name,
          fetch: widget.fetch,
          interval: LiveDefaults.gridInterval,
          onAuthError: widget.onAuthError,
        ),
      );
      if (feed.height != height) {
        feed
          ..stop()
          ..height = height;
      }
      if (!_paused && visible.contains(camera.name)) {
        feed.start();
      } else {
        feed.stop();
      }
    }
  }

  List<CameraCapabilities> _camerasOfPage(int page) {
    final start = page * widget.layout;
    if (start >= widget.cameras.length) return const [];
    return widget.cameras.sublist(
      start,
      math.min(start + widget.layout, widget.cameras.length),
    );
  }

  List<CameraCapabilities> _visibleCameras() => _camerasOfPage(_page);

  Future<void> _openFullScreen(CameraCapabilities camera) async {
    setState(() => _paused = true);
    _syncFeeds();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraFullScreen(
          cameras: widget.cameras,
          initialCamera: camera.name,
          fetch: widget.fetch,
          videoFactory: widget.videoFactory,
          onAuthError: widget.onAuthError,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _paused = false);
    _syncFeeds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final feed in _feeds.values) {
      feed.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.cameras.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.liveNoCamera,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final columns = math.sqrt(widget.layout).round();
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pageCount,
            onPageChanged: (page) {
              setState(() => _page = page);
              _syncFeeds();
            },
            itemBuilder: (context, page) => _GridPage(
              cameras: _camerasOfPage(page),
              columns: columns,
              feeds: _feeds,
              onTap: _openFullScreen,
            ),
          ),
        ),
        if (_pageCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              label: l.livePage(_page + 1, _pageCount),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 6,
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppColors.accent
                            : AppColors.surfaceHigh,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GridPage extends StatelessWidget {
  final List<CameraCapabilities> cameras;
  final int columns;
  final Map<String, CameraFeed> feeds;
  final ValueChanged<CameraCapabilities> onTap;

  const _GridPage({
    required this.cameras,
    required this.columns,
    required this.feeds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 16 / 9,
      ),
      itemCount: cameras.length,
      itemBuilder: (context, i) {
        final camera = cameras[i];
        final feed = feeds[camera.name];
        if (feed == null) return const SizedBox.shrink();
        return FeedTile(
          key: ValueKey(camera.name),
          feed: feed,
          label: camera.label,
          onTap: () => onTap(camera),
        );
      },
    );
  }
}
