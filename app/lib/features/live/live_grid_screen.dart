import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';
import 'camera_feed.dart';
import 'camera_full_screen.dart';
import 'feed_tile.dart';
import 'grid_fit.dart';
import 'live_video.dart';
import 'ptz_pad.dart';

/// Automatic layout: as many cameras per page as the screen shows well.
const liveLayoutAuto = 0;

/// Grid layouts offered in the app bar: automatic, then 1, 4 or 9 cameras
/// per page.
const liveLayouts = [liveLayoutAuto, 1, 4, 9];

/// Layout of the grid when nothing was chosen yet.
const liveLayoutDefault = liveLayoutAuto;

/// "Direct" tab (mock-up screen 2): every camera in pages of thumbnails
/// sized to fill the screen, refreshed while visible; a tap opens the full
/// screen.
class LiveGridScreen extends StatefulWidget {
  final List<CameraCapabilities> cameras;
  final ImageFetcher fetch;
  final LiveVideoFactory? videoFactory;

  /// [liveLayoutAuto] or a fixed number of cameras per page.
  final int layout;
  final VoidCallback? onAuthError;

  /// Narrowest tile of the automatic layout.
  final double minTileWidth;

  /// Passed on to the full screen.
  final bool lightStreamFirst;
  final bool tryOtherStreams;
  final bool videoOnly;

  /// Passed on to the full screen: "Talk" allowed on a camera.
  final bool Function(String camera)? talkAllowed;

  /// Pan, tilt and zoom in full screen; null hides them.
  final PtzSource? ptz;

  const LiveGridScreen({
    super.key,
    required this.cameras,
    required this.fetch,
    this.videoFactory,
    this.layout = liveLayoutDefault,
    this.onAuthError,
    this.minTileWidth = GridFitDefaults.minTileWidth,
    this.lightStreamFirst = false,
    this.tryOtherStreams = LiveVideoDefaults.tryOtherStreams,
    this.videoOnly = false,
    this.talkAllowed,
    this.ptz,
  });

  @override
  State<LiveGridScreen> createState() => _LiveGridScreenState();
}

class _LiveGridScreenState extends State<LiveGridScreen>
    with WidgetsBindingObserver {
  /// Height of the page dots under the grid.
  static const _dotsHeight = 15.0;

  final _feeds = <String, CameraFeed>{};
  final _pageController = PageController();
  int _page = 0;
  bool _paused = false;

  /// Cameras per page and thumbnail height of the last layout; known once
  /// the screen size is.
  int? _perPage;
  int _thumbnailHeight = 360;

  int get _pageCount =>
      math.max(1, (widget.cameras.length / (_perPage ?? 1)).ceil());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(LiveGridScreen old) {
    super.didUpdateWidget(old);
    if (old.fetch != widget.fetch) {
      for (final feed in _feeds.values) {
        feed.dispose();
      }
      _feeds.clear();
    }
    // Fewer cameras (some hidden): the page shown stays within the pages.
    if (_page >= _pageCount) {
      _page = _pageCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_page);
        }
      });
    }
    if (_perPage != null) _syncFeeds();
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
    if (_perPage == null) return;
    final names = {for (final c in widget.cameras) c.name};
    for (final name in _feeds.keys.toList()) {
      if (!names.contains(name)) {
        _feeds.remove(name)!.dispose();
      }
    }
    final visible = _visibleCameras().map((c) => c.name).toSet();
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
      if (feed.height != _thumbnailHeight) {
        feed
          ..stop()
          ..height = _thumbnailHeight;
      }
      if (!_paused && visible.contains(camera.name)) {
        feed.start();
      } else {
        feed.stop();
      }
    }
  }

  List<CameraCapabilities> _camerasOfPage(int page) {
    final perPage = _perPage ?? 1;
    final start = page * perPage;
    if (start >= widget.cameras.length) return const [];
    return widget.cameras.sublist(
      start,
      math.min(start + perPage, widget.cameras.length),
    );
  }

  List<CameraCapabilities> _visibleCameras() => _camerasOfPage(_page);

  /// Layout of the grid in [size]: room is kept for the page dots only
  /// when there are several pages.
  GridFit _fit(Size size) {
    final count = widget.cameras.length;
    GridFit fitIn(double bottom) {
      final area = Size(
        math.max(0, size.width - 2 * GridFitDefaults.padding),
        math.max(0, size.height - 2 * GridFitDefaults.padding - bottom),
      );
      return widget.layout == liveLayoutAuto
          ? fitAuto(count, area, minTileWidth: widget.minTileWidth)
          : fitFixed(math.min(widget.layout, count), area);
    }

    final fit = fitIn(0);
    return fit.perPage < count ? fitIn(_dotsHeight) : fit;
  }

  /// Takes a new layout (first build, other layout chosen, screen turned):
  /// the first camera of the page stays in view, feeds follow.
  void _apply(GridFit fit, double pixelRatio) {
    final height = LiveDefaults.thumbnailHeightFor(
      fit.tile.height * pixelRatio,
    );
    if (fit.perPage == _perPage && height == _thumbnailHeight) return;
    final first = _page * (_perPage ?? fit.perPage);
    _perPage = fit.perPage;
    _thumbnailHeight = height;
    _page = math.min(first ~/ fit.perPage, _pageCount - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients &&
          _pageController.page?.round() != _page) {
        _pageController.jumpToPage(_page);
      }
      // Feeds are made outside the build; tiles show them on the next one.
      setState(_syncFeeds);
    });
  }

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
          lightStreamFirst: widget.lightStreamFirst,
          tryOtherStreams: widget.tryOtherStreams,
          videoOnly: widget.videoOnly,
          talkAllowed: widget.talkAllowed,
          ptz: widget.ptz,
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
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = _fit(constraints.biggest);
        _apply(fit, pixelRatio);
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
                  fit: fit,
                  feeds: _feeds,
                  onTap: _openFullScreen,
                ),
              ),
            ),
            if (_pageCount > 1)
              SizedBox(
                height: _dotsHeight,
                child: Semantics(
                  label: l.livePage(_page + 1, _pageCount),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
      },
    );
  }
}

/// One page of tiles, all the same size, centred; an incomplete last row
/// is centred too.
class _GridPage extends StatelessWidget {
  final List<CameraCapabilities> cameras;
  final GridFit fit;
  final Map<String, CameraFeed> feeds;
  final ValueChanged<CameraCapabilities> onTap;

  const _GridPage({
    required this.cameras,
    required this.fit,
    required this.feeds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GridFitDefaults.padding),
      child: Center(
        child: SizedBox(
          width: fit.grid.width,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: GridFitDefaults.spacing,
            runSpacing: GridFitDefaults.spacing,
            children: [
              for (final camera in cameras)
                SizedBox.fromSize(
                  size: fit.tile,
                  child: switch (feeds[camera.name]) {
                    final feed? => FeedTile(
                      key: ValueKey(camera.name),
                      feed: feed,
                      label: camera.label,
                      onTap: () => onTap(camera),
                    ),
                    null => const SizedBox.shrink(),
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
