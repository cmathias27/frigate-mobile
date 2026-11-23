import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/frigate/capabilities.dart';
import '../core/storage/preferences.dart';
import '../features/timeline/motion_passages.dart';

/// Stream a live video opens first.
enum LiveQuality {
  /// Main stream in full screen, the lightest one in the timeline.
  auto,

  /// Main stream everywhere.
  high,

  /// Lightest stream everywhere: less data, any phone decodes it.
  light,
}

/// Smallest width of a tile in the automatic live grid: wider tiles mean
/// fewer cameras per page.
enum TileSize {
  small(120),
  medium(150),
  large(200);

  final double width;
  const TileSize(this.width);
}

/// Values used while nothing was chosen (decision 0002).
abstract final class SettingsDefaults {
  static const quality = LiveQuality.auto;
  static const tryOtherStreams = true;
  static const imageFallback = true;
  static const tileSize = TileSize.medium;
  static const minPassage = Duration.zero;
  static const mergeGap = Duration(seconds: 30);

  /// Choices offered for the passages.
  static const minPassages = [
    Duration.zero,
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];
  static const mergeGaps = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
  ];
}

/// The settings of the app, kept in the preferences as one JSON document.
/// Cameras are named as Frigate names them; a camera gone from the server
/// keeps its settings, harmlessly, until it comes back.
class AppSettings extends ChangeNotifier {
  static const key = 'fm_settings';

  final Preferences? _preferences;

  List<String> _order = const [];
  Set<String> _hidden = const {};
  Map<String, int> _thresholds = const {};
  LiveQuality _quality = SettingsDefaults.quality;
  bool _tryOtherStreams = SettingsDefaults.tryOtherStreams;
  bool _imageFallback = SettingsDefaults.imageFallback;
  TileSize _tileSize = SettingsDefaults.tileSize;
  Duration _minPassage = SettingsDefaults.minPassage;
  Duration _mergeGap = SettingsDefaults.mergeGap;
  bool _disposed = false;

  AppSettings([this._preferences]);

  /// Reads the stored settings; anything missing or unreadable keeps its
  /// default value.
  Future<void> load() async {
    final stored = await _preferences?.read(key);
    if (stored == null || _disposed) return;
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      return;
    }
    if (json is! Map) return;
    final Map<Object?, Object?> map = json;
    T? pick<T>(String name) => map[name] is T ? map[name] as T : null;
    E? named<E extends Enum>(List<E> values, String name) {
      final value = pick<String>(name);
      for (final e in values) {
        if (e.name == value) return e;
      }
      return null;
    }

    _order = [...?pick<List<Object?>>('order')?.whereType<String>()];
    _hidden = {...?pick<List<Object?>>('hidden')?.whereType<String>()};
    _thresholds = {
      for (final MapEntry(:key, :value)
          in (pick<Map<Object?, Object?>>('thresholds') ?? const {}).entries)
        if (key is String && value is int && value > 0) key: value,
    };
    _quality = named(LiveQuality.values, 'quality') ?? _quality;
    _tileSize = named(TileSize.values, 'tileSize') ?? _tileSize;
    _tryOtherStreams = pick<bool>('tryOtherStreams') ?? _tryOtherStreams;
    _imageFallback = pick<bool>('imageFallback') ?? _imageFallback;
    final minPassage = pick<int>('minPassage');
    if (minPassage != null && minPassage >= 0) {
      _minPassage = Duration(seconds: minPassage);
    }
    final mergeGap = pick<int>('mergeGap');
    if (mergeGap != null && mergeGap >= 0) {
      _mergeGap = Duration(seconds: mergeGap);
    }
    notifyListeners();
  }

  LiveQuality get quality => _quality;
  bool get tryOtherStreams => _tryOtherStreams;
  bool get imageFallback => _imageFallback;
  TileSize get tileSize => _tileSize;
  Duration get minPassage => _minPassage;
  Duration get mergeGap => _mergeGap;

  set quality(LiveQuality value) => _change(() => _quality = value);
  set tryOtherStreams(bool value) => _change(() => _tryOtherStreams = value);
  set imageFallback(bool value) => _change(() => _imageFallback = value);
  set tileSize(TileSize value) => _change(() => _tileSize = value);
  set minPassage(Duration value) => _change(() => _minPassage = value);
  set mergeGap(Duration value) => _change(() => _mergeGap = value);

  /// The full screen opens the lightest stream first.
  bool get fullScreenLightFirst => _quality == LiveQuality.light;

  /// The timeline opens the lightest stream first.
  bool get timelineLightFirst => _quality != LiveQuality.high;

  bool hidden(String camera) => _hidden.contains(camera);

  void setHidden(String camera, bool hidden) => _change(() {
    _hidden = hidden ? {..._hidden, camera} : ({..._hidden}..remove(camera));
  });

  /// Fixed motion threshold of [camera], `null` when automatic.
  int? threshold(String camera) => _thresholds[camera];

  void setThreshold(String camera, int? value) => _change(() {
    final next = {..._thresholds}..remove(camera);
    if (value != null && value > 0) next[camera] = value;
    _thresholds = next;
  });

  /// [cameras] in the order chosen, cameras never ordered after in the
  /// server's order; hidden ones left out unless [withHidden].
  List<CameraCapabilities> arrange(
    Iterable<CameraCapabilities> cameras, {
    bool withHidden = false,
  }) {
    final all = cameras.toList();
    int rank(CameraCapabilities c) {
      final i = _order.indexOf(c.name);
      return i < 0 ? _order.length + all.indexOf(c) : i;
    }

    return [
      for (final c in all..sort((a, b) => rank(a).compareTo(rank(b))))
        if (withHidden || !_hidden.contains(c.name)) c,
    ];
  }

  /// Keeps [cameras] in this order.
  void reorder(List<String> cameras) => _change(() => _order = [...cameras]);

  /// How the timeline finds motion passages.
  PassageSettings get passages => PassageSettings(
    minDuration: _minPassage,
    mergeGap: _mergeGap,
    thresholds: Map.unmodifiable(_thresholds),
  );

  void _change(void Function() change) {
    change();
    notifyListeners();
    unawaited(_preferences?.write(key, jsonEncode(_toJson())));
  }

  Map<String, Object> _toJson() => {
    'order': _order,
    'hidden': _hidden.toList(),
    'thresholds': _thresholds,
    'quality': _quality.name,
    'tryOtherStreams': _tryOtherStreams,
    'imageFallback': _imageFallback,
    'tileSize': _tileSize.name,
    'minPassage': _minPassage.inSeconds,
    'mergeGap': _mergeGap.inSeconds,
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
