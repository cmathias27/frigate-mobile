import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/frigate/client.dart';
import '../../core/frigate/recordings.dart';
import 'motion_passages.dart';

/// Reads the segments of a camera between two times.
typedef RecordingsFetcher = Future<List<RecordingSegment>> Function(
  String camera,
  DateTime after,
  DateTime before,
);

abstract final class TimelineDefaults {
  /// Segments are fetched and cached by hour of each camera: about 360
  /// segments, 200 kB.
  static const chunk = Duration(hours: 1);

  /// Requests sent to Frigate at the same time.
  static const concurrency = 3;

  /// Most hours fetched for a visible window, all cameras together. Past
  /// it (24 h and whole-history zooms), only the camera being played is
  /// filled in.
  static const windowBudget = 48;

  /// How far "previous" and "next" look for a passage.
  static const seekLimit = Duration(hours: 24);

  /// An hour still being recorded is fetched again after this delay.
  static const liveRefresh = Duration(seconds: 30);

  /// A failed hour is retried after this delay.
  static const retryDelay = Duration(seconds: 20);
}

class _Chunk {
  final List<RecordingSegment> segments;
  final DateTime fetchedAt;
  const _Chunk(this.segments, this.fetchedAt);
}

typedef _Key = ({String camera, int index});

/// Segments, coverage and motion passages of every camera, fetched by hour
/// as the timeline shows them and kept for the session.
class TimelineData extends ChangeNotifier {
  final List<String> cameras;
  final RecordingsFetcher _fetch;
  PassageSettings _settings;
  final DateTime Function() _now;
  final void Function()? onAuthError;

  final _chunks = <String, Map<int, _Chunk>>{};
  final _failedAt = <_Key, DateTime>{};
  final _inflight = <_Key, Future<void>>{};
  var _queue = <_Key>[];
  final _cache = <String, _Derived>{};
  bool _disposed = false;

  TimelineData({
    required this.cameras,
    required this._fetch,
    this._settings = const PassageSettings(),
    DateTime Function()? clock,
    this.onAuthError,
  }) : _now = clock ?? DateTime.now;

  PassageSettings get settings => _settings;

  /// New passage settings: passages are found again in the hours fetched.
  set settings(PassageSettings value) {
    _settings = value;
    _cache.clear();
    if (!_disposed) notifyListeners();
  }

  /// True while hours are being fetched.
  bool get loading => _inflight.isNotEmpty || _queue.isNotEmpty;

  /// Fetches the hours of the window [from]–[to] that are missing, the
  /// camera [focus] first, then outwards from the middle. Hours asked
  /// earlier and not yet started are dropped.
  void ensure(DateTime from, DateTime to, {required String focus}) {
    final now = _now();
    if (to.isAfter(now)) to = now;
    if (!from.isBefore(to)) {
      _queue = [];
      return;
    }
    final first = _index(from);
    final last = _index(to.subtract(const Duration(milliseconds: 1)));
    final middle = _index(from.add(to.difference(from) ~/ 2));
    final hours = [for (var i = first; i <= last; i++) i]
      ..sort((a, b) => (a - middle).abs().compareTo((b - middle).abs()));
    final wide = hours.length * cameras.length > TimelineDefaults.windowBudget;
    final ordered = [
      if (cameras.contains(focus)) focus,
      for (final c in cameras)
        if (c != focus && !wide) c,
    ];
    final wanted = <_Key>[
      for (final index in hours)
        for (final camera in ordered)
          if (_needs((camera: camera, index: index), now))
            (camera: camera, index: index),
    ];
    // Hours closest to the middle first; within an hour, the focus first.
    _queue = wanted.take(TimelineDefaults.windowBudget * 2).toList();
    _pump();
    notifyListeners();
  }

  /// Segments of [camera] in time order, from every hour fetched so far.
  List<RecordingSegment> segments(String camera) => _derived(camera).segments;

  /// Recorded stretches of [camera] among the hours fetched.
  List<Coverage> coverage(String camera) => _derived(camera).coverage;

  /// Automatic (or set) passage threshold of [camera].
  int threshold(String camera) => _derived(camera).threshold;

  /// Passages of [camera] in time order.
  List<MotionPassage> passages(String camera) => _derived(camera).passages;

  /// Passages of every camera in time order.
  List<MotionPassage> allPassages() =>
      [for (final c in cameras) ...passages(c)]
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Whether the hour holding [time] has been fetched for [camera].
  bool isLoaded(String camera, DateTime time) =>
      _chunks[camera]?.containsKey(_index(time)) ?? false;

  /// The passage next to [from]: the first one starting after it, or the
  /// last one starting before it, of [camera] only when given, of any
  /// camera otherwise. Hours are fetched outwards until one is found or
  /// [TimelineDefaults.seekLimit] is reached.
  Future<MotionPassage?> seekPassage(
    DateTime from, {
    required bool forward,
    String? camera,
  }) async {
    final searched = camera == null ? cameras : [camera];
    final base = _index(from);
    final steps =
        TimelineDefaults.seekLimit.inMilliseconds ~/
        TimelineDefaults.chunk.inMilliseconds;
    for (var step = 0; step <= steps && !_disposed; step++) {
      final index = forward ? base + step : base - step;
      final chunkStart = _start(index);
      if (forward && chunkStart.isAfter(_now())) break;
      final now = _now();
      await Future.wait([
        for (final c in searched)
          if (_inflight[(camera: c, index: index)] case final pending?)
            pending
          else if (_needs((camera: c, index: index), now))
            _load((camera: c, index: index)),
      ]);
      final found = _neighbour(from, forward: forward, camera: camera);
      if (found == null) continue;
      final reached = forward
          ? found.start.isBefore(_start(index + 1))
          : !found.start.isBefore(chunkStart);
      if (reached) return found;
    }
    return null;
  }

  /// Start of the hour of fetching that holds [time].
  DateTime hourStart(DateTime time) => _start(_index(time));

  /// Fetches the hour holding [time] for every camera and waits for it.
  /// Returns false when a camera could not be read.
  Future<bool> loadHour(DateTime time) async {
    final index = _index(time);
    final now = _now();
    await Future.wait([
      for (final camera in cameras)
        if (_inflight[(camera: camera, index: index)] case final pending?)
          pending
        else if (_needs((camera: camera, index: index), now))
          _load((camera: camera, index: index)),
    ]);
    return cameras.every((c) => isLoaded(c, time));
  }

  MotionPassage? _neighbour(
    DateTime from, {
    required bool forward,
    String? camera,
  }) {
    final all = camera == null ? allPassages() : passages(camera);
    if (forward) {
      final after = from.add(const Duration(seconds: 1));
      for (final p in all) {
        if (p.start.isAfter(after)) return p;
      }
      return null;
    }
    // Slightly before, so a second press goes past the passage being played.
    final before = from.subtract(const Duration(seconds: 2));
    for (final p in all.reversed) {
      if (p.start.isBefore(before)) return p;
    }
    return null;
  }

  bool _needs(_Key key, DateTime now) {
    if (_inflight.containsKey(key)) return false;
    final failed = _failedAt[key];
    if (failed != null &&
        now.difference(failed) < TimelineDefaults.retryDelay) {
      return false;
    }
    final chunk = _chunks[key.camera]?[key.index];
    if (chunk == null) return true;
    // An hour fetched before its end is still being recorded.
    final complete = !chunk.fetchedAt.isBefore(_start(key.index + 1));
    return !complete &&
        now.difference(chunk.fetchedAt) >= TimelineDefaults.liveRefresh;
  }

  void _pump() {
    while (_inflight.length < TimelineDefaults.concurrency &&
        _queue.isNotEmpty &&
        !_disposed) {
      final key = _queue.removeAt(0);
      if (!_needs(key, _now())) continue;
      unawaited(_load(key).whenComplete(_pump));
    }
  }

  Future<void> _load(_Key key) =>
      _inflight[key] ??= _fetchChunk(key).whenComplete(() {
        _inflight.remove(key);
        if (!_disposed) notifyListeners();
      });

  Future<void> _fetchChunk(_Key key) async {
    try {
      final fetchedAt = _now();
      final segments = await _fetch(
        key.camera,
        _start(key.index),
        _start(key.index + 1),
      );
      if (_disposed) return;
      (_chunks[key.camera] ??= {})[key.index] = _Chunk(segments, fetchedAt);
      _failedAt.remove(key);
      _cache.remove(key.camera);
    } on FrigateAuthException {
      _queue = [];
      _failedAt[key] = _now();
      onAuthError?.call();
    } catch (_) {
      _failedAt[key] = _now();
    }
  }

  _Derived _derived(String camera) => _cache[camera] ??= _Derived.build(
    camera,
    _chunks[camera] ?? const {},
    settings,
  );

  int _index(DateTime time) =>
      time.millisecondsSinceEpoch ~/ TimelineDefaults.chunk.inMilliseconds;

  DateTime _start(int index) => DateTime.fromMillisecondsSinceEpoch(
    index * TimelineDefaults.chunk.inMilliseconds,
  );

  @override
  void dispose() {
    _disposed = true;
    _queue = [];
    super.dispose();
  }
}

/// What the timeline draws for one camera, rebuilt when an hour arrives.
class _Derived {
  final List<RecordingSegment> segments;
  final List<Coverage> coverage;
  final int threshold;
  final List<MotionPassage> passages;

  const _Derived(this.segments, this.coverage, this.threshold, this.passages);

  factory _Derived.build(
    String camera,
    Map<int, _Chunk> chunks,
    PassageSettings settings,
  ) {
    final indexes = chunks.keys.toList()..sort();
    final segments = <RecordingSegment>[];
    for (final index in indexes) {
      for (final s in chunks[index]!.segments) {
        // A segment across the hour boundary comes with both hours.
        if (segments.isNotEmpty && !s.start.isAfter(segments.last.start)) {
          continue;
        }
        segments.add(s);
      }
    }
    settings = settings.forCamera(camera);
    final threshold = passageThreshold(
      segments.map((s) => s.motion),
      settings,
    );
    return _Derived(
      List.unmodifiable(segments),
      recordingCoverage(segments),
      threshold,
      findPassages(camera, segments, threshold, settings),
    );
  }
}

/// Smallest and largest of two times.
DateTime minTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
DateTime maxTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Hours shown by each zoom of the timeline; `null` is the whole history.
const timelineZooms = <Duration?>[
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 24),
  null,
];

/// Width of the whole-history zoom: the longest retention of the cameras,
/// at least a day.
Duration historySpan(Iterable<double> retentionDays) {
  final days = retentionDays.fold<double>(1, max);
  return Duration(minutes: (days * 24 * 60).ceil());
}
