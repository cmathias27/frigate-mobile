import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/frigate/client.dart';

/// Reads one frame of a camera; [height] asks Frigate for a smaller image.
typedef ImageFetcher = Future<Uint8List> Function(String camera, {int? height});

/// Default refresh settings of the live view (decision 0002: a default
/// value now, an optional setting later).
abstract final class LiveDefaults {
  /// Delay between two frames of a grid thumbnail.
  static const gridInterval = Duration(seconds: 2);

  /// Delay between two frames of the full-screen view.
  static const fullScreenInterval = Duration(seconds: 1);

  /// Thumbnail height asked to Frigate for each grid layout.
  static int thumbnailHeight(int layout) => switch (layout) {
    1 => 720,
    4 => 360,
    _ => 240,
  };
}

/// Keeps the latest frame of one camera fresh while started.
///
/// A new request starts only once the previous one has finished, so a slow
/// network never piles requests up.
class CameraFeed extends ChangeNotifier {
  final String camera;
  final ImageFetcher _fetch;
  final Duration interval;
  final DateTime Function() _clock;

  /// Called when Frigate refuses the session token.
  final VoidCallback? onAuthError;

  int? height;

  Uint8List? _image;
  DateTime? _updatedAt;
  bool _failed = false;
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _timer;

  CameraFeed({
    required this.camera,
    required this._fetch,
    this.height,
    this.interval = LiveDefaults.gridInterval,
    this.onAuthError,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Last frame received, kept while new ones fail.
  Uint8List? get image => _image;

  /// When [image] was received.
  DateTime? get updatedAt => _updatedAt;

  /// The last request failed.
  bool get failed => _failed;

  bool get isRunning => _running;

  /// True when no recent frame arrived: the badge then stops saying "live".
  bool get isStale {
    final at = _updatedAt;
    if (at == null || _failed) return true;
    return _clock().difference(at) > interval * 3 + const Duration(seconds: 3);
  }

  void start() {
    if (_running || _disposed) return;
    _running = true;
    _tick(++_generation);
  }

  void stop() {
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick(int generation) async {
    try {
      final bytes = await _fetch(camera, height: height);
      if (_disposed || generation != _generation) return;
      _image = bytes;
      _updatedAt = _clock();
      _failed = false;
    } on FrigateAuthException {
      if (_disposed || generation != _generation) return;
      _failed = true;
      stop();
      notifyListeners();
      onAuthError?.call();
      return;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _failed = true;
    }
    notifyListeners();
    if (_running && generation == _generation) {
      _timer = Timer(interval, () => _tick(generation));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
