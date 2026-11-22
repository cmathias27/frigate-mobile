import 'package:flutter/foundation.dart';

import '../../core/frigate/reviews.dart';
import 'thumbnails.dart';

typedef ReviewFetcher = Future<List<ReviewItem>> Function({
  required DateTime after,
  required DateTime before,
  ReviewSeverity? severity,
  List<String>? cameras,
  int? limit,
});

typedef ReviewMarker = Future<void> Function(List<String> ids, {bool reviewed});

abstract final class ReviewListDefaults {
  /// Time read when the list opens, and each time it goes further back.
  static const page = Duration(days: 1);
}

/// What the Alerts tab lists (mock-up screen 5).
enum EventsView { alerts, detections, motion }

/// Alerts and detections of Frigate for the Alerts tab, newest first, read
/// a day at a time, with the "seen" mark Frigate keeps for each user.
class ReviewList extends ChangeNotifier {
  final ReviewFetcher _fetch;
  final ReviewMarker _mark;

  /// Cameras listed, those of the tab.
  final List<String> cameras;

  /// How far back the list may go: the longest retention of the cameras.
  final Duration history;
  final DateTime Function() _clock;

  EventsView _view = EventsView.alerts;

  final _byId = <String, ReviewItem>{};
  String? _camera;
  DateTime? _from;
  DateTime? _readAt;
  bool _loading = false;
  bool _failed = false;
  bool _disposed = false;

  ReviewList({
    required this._fetch,
    required this._mark,
    required this.cameras,
    required this.history,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Section shown; alerts first, kept while the app runs.
  EventsView get view => _view;
  set view(EventsView view) {
    if (view == _view) return;
    _view = view;
    _notify();
  }

  /// Camera filter, `null` for every camera.
  String? get camera => _camera;
  set camera(String? name) {
    if (name == _camera) return;
    _camera = name;
    _notify();
  }

  /// Start of the time read so far, `null` before the first answer.
  DateTime? get from => _from;
  bool get loading => _loading;
  bool get failed => _failed;
  bool get reachedEnd {
    final from = _from;
    final readAt = _readAt;
    return from != null &&
        readAt != null &&
        !from.isAfter(readAt.subtract(history));
  }

  /// Items of [severity] for the camera filter, newest first.
  List<ReviewItem> items(ReviewSeverity severity) => [
    for (final item in _sorted)
      if (item.severity == severity &&
          (_camera == null || item.camera == _camera))
        item,
  ];

  /// Items not seen yet, of [severity] or of both, for the camera filter.
  int unseen([ReviewSeverity? severity]) => _sorted
      .where(
        (i) =>
            !i.reviewed &&
            (severity == null || i.severity == severity) &&
            (_camera == null || i.camera == _camera),
      )
      .length;

  List<ReviewItem> get _sorted =>
      _byId.values.toList()..sort((a, b) => b.start.compareTo(a.start));

  /// Reads the last day once; later calls keep what was read.
  Future<void> open() async {
    if (_from != null || _loading) return;
    await refresh();
  }

  /// Reads the last day again, dropping what was read before.
  Future<void> refresh() async {
    final now = _clock();
    _byId.clear();
    _from = null;
    _readAt = now;
    await _load(now.subtract(ReviewListDefaults.page), now, first: true);
  }

  /// Reads the day before the oldest one read.
  Future<void> loadMore() async {
    final from = _from;
    if (from == null || _loading || reachedEnd) return;
    await _load(from.subtract(ReviewListDefaults.page), from);
  }

  /// After a failure: reads again what failed.
  Future<void> retry() => _from == null ? refresh() : loadMore();

  Future<void> _load(
    DateTime after,
    DateTime before, {
    bool first = false,
  }) async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      final items = await _fetch(
        after: after,
        before: before,
        cameras: cameras,
      );
      if (_disposed) return;
      for (final item in items) {
        if (cameras.contains(item.camera)) _byId[item.id] = item;
      }
      _from = after;
    } catch (_) {
      if (_disposed) return;
      _failed = true;
    } finally {
      _loading = false;
    }
    _notify();
  }

  /// Marks [targets] seen, or not seen, at once on screen; undone when
  /// Frigate refuses. Returns whether Frigate took it.
  Future<bool> mark(
    Iterable<ReviewItem> targets, {
    bool reviewed = true,
  }) async {
    final changed = [
      for (final t in targets)
        if (_byId[t.id] case final item? when item.reviewed != reviewed) item,
    ];
    if (changed.isEmpty) return true;
    for (final item in changed) {
      _byId[item.id] = item.copyWith(reviewed: reviewed);
    }
    _notify();
    try {
      await _mark([for (final i in changed) i.id], reviewed: reviewed);
      return true;
    } catch (_) {
      for (final item in changed) {
        if (_byId.containsKey(item.id)) _byId[item.id] = item;
      }
      _notify();
      return false;
    }
  }

  /// Marks every item of [severity] shown as seen.
  Future<bool> markAllSeen(ReviewSeverity severity) =>
      mark(items(severity).where((i) => !i.reviewed));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Review thumbnails, fetched once while they stay in memory; a failed one
/// is asked again the next time it is shown.
class ReviewThumbnails {
  final Future<Uint8List> Function(String path) _fetch;
  final int kept;
  final _images = <String, Future<Uint8List>>{};

  ReviewThumbnails(this._fetch, {this.kept = ThumbnailDefaults.kept});

  Future<Uint8List> of(String path) {
    final cached = _images.remove(path);
    if (cached != null) return _images[path] = cached;
    final future = _fetch(path);
    _images[path] = future;
    future.catchError((Object _) {
      if (identical(_images[path], future)) _images.remove(path);
      return Uint8List(0);
    });
    while (_images.length > kept) {
      _images.remove(_images.keys.first);
    }
    return future;
  }
}
