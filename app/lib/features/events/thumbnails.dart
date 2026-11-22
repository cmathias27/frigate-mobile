import 'dart:typed_data';

/// Reads a recorded frame of a camera, scaled to a thumbnail.
typedef RecordingImageFetcher = Future<Uint8List> Function(
  String camera,
  DateTime time,
);

abstract final class ThumbnailDefaults {
  /// Height asked to Frigate: about 9 kB a thumbnail.
  static const height = 180;

  /// Thumbnails kept in memory, the least recently shown dropped first.
  static const kept = 80;
}

/// Thumbnails of the list, fetched once while they stay in memory; a failed
/// one is asked again the next time it is shown.
class RecordingThumbnails {
  final RecordingImageFetcher _fetch;
  final int kept;
  // Insertion order is the order of use: a map literal keeps it.
  final _images = <String, Future<Uint8List>>{};

  RecordingThumbnails(this._fetch, {this.kept = ThumbnailDefaults.kept});

  Future<Uint8List> of(String camera, DateTime time) {
    final key = '$camera@${time.millisecondsSinceEpoch}';
    final cached = _images.remove(key);
    if (cached != null) return _images[key] = cached;
    final future = _fetch(camera, time);
    _images[key] = future;
    future.catchError((Object _) {
      if (identical(_images[key], future)) _images.remove(key);
      return Uint8List(0);
    });
    while (_images.length > kept) {
      _images.remove(_images.keys.first);
    }
    return future;
  }
}
