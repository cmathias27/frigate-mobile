import 'package:flutter/foundation.dart';

import '../../core/storage/preferences.dart';
import '../timeline/motion_passages.dart';
import '../timeline/timeline_data.dart';

abstract final class MotionListDefaults {
  /// Hours read when the list opens, and each time it goes further back:
  /// about 230 kB per hour and camera.
  static const page = 3;
}

/// The motion passages of the Alerts tab, newest first: the same passages
/// as the timeline, read from the same hours (shared [TimelineData]), and
/// the time up to which they have been seen.
class MotionList extends ChangeNotifier {
  static const _keySeenUntil = 'fm_events_seen_until';

  final TimelineData data;

  /// How far back the list may go: the longest retention of the cameras.
  final Duration history;
  final Preferences _preferences;
  final DateTime Function() _clock;

  DateTime? _from;
  DateTime? _seenUntil;
  bool _seenRead = false;
  bool _loading = false;
  bool _failed = false;
  bool _moreFailed = false;
  String? _camera;
  bool _disposed = false;

  MotionList({
    required this.data,
    required this.history,
    required this._preferences,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    data.addListener(_notify);
  }

  /// Start of the oldest hour read, `null` before the first one.
  DateTime? get from => _from;
  bool get loading => _loading;

  /// True when the last hours could not be read; [loadMore] retries.
  bool get failed => _failed;

  /// True once the list reaches the oldest recording kept.
  bool get reachedEnd {
    final from = _from;
    return from != null && !from.isAfter(_clock().subtract(history));
  }

  /// Camera shown alone, or `null` for every camera.
  String? get camera => _camera;
  set camera(String? value) {
    if (value == _camera) return;
    _camera = value;
    notifyListeners();
  }

  /// Passages of the hours read, newest first.
  List<MotionPassage> get passages {
    final from = _from;
    if (from == null) return const [];
    return [
      for (final p in data.allPassages().reversed)
        if (!p.start.isBefore(from) && (_camera == null || p.camera == _camera))
          p,
    ];
  }

  /// A passage that started after the last visit of the list. Nothing is
  /// new at the very first visit.
  bool isNew(MotionPassage passage) {
    final seen = _seenUntil;
    return seen != null && passage.start.isAfter(seen);
  }

  int get newCount => passages.where(isNew).length;

  /// Reads the last hours, once.
  Future<void> open() async {
    if (!_seenRead) {
      _seenRead = true;
      _seenUntil = DateTime.tryParse(
        await _preferences.read(_keySeenUntil) ?? '',
      );
    }
    if (_from == null) {
      await loadMore();
    } else {
      await refresh();
    }
  }

  /// Reads [MotionListDefaults.page] more hours, back in time.
  Future<void> loadMore() async {
    if (_loading || reachedEnd) return;
    _loading = true;
    _failed = false;
    _notify();
    final start = _from ?? data.hourStart(_clock()).add(TimelineDefaults.chunk);
    for (var i = 1; i <= MotionListDefaults.page && !_disposed; i++) {
      final hour = start.subtract(TimelineDefaults.chunk * i);
      if (!await data.loadHour(hour)) {
        _failed = true;
        break;
      }
      _from = hour;
      _notify();
      if (reachedEnd) break;
    }
    _moreFailed = _failed;
    _loading = false;
    _notify();
  }

  /// After a failure: reads the recent hours again, then the older ones
  /// that could not be read.
  Future<void> retry() async {
    await refresh();
    if (!_failed && _moreFailed) await loadMore();
  }

  /// Reads the hours begun since the list opened, and the one being
  /// recorded again; complete hours are not fetched twice.
  Future<void> refresh() async {
    final from = _from;
    if (from == null) return loadMore();
    if (_loading) return;
    _loading = true;
    _notify();
    var hour = data.hourStart(_clock());
    var ok = true;
    while (!hour.isBefore(from) && !_disposed) {
      ok = await data.loadHour(hour) && ok;
      hour = hour.subtract(TimelineDefaults.chunk);
    }
    _failed = !ok;
    _loading = false;
    _notify();
  }

  /// Every passage shown is now seen.
  Future<void> markSeen() async {
    final all = data.allPassages();
    if (all.isEmpty && _seenUntil != null) return;
    final newest = all.isEmpty ? _clock() : all.last.start;
    if (_seenUntil != null && !newest.isAfter(_seenUntil!)) return;
    _seenUntil = newest;
    await _preferences.write(_keySeenUntil, newest.toIso8601String());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    data.removeListener(_notify);
    super.dispose();
  }
}
