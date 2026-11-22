import 'dart:async';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/frigate/client.dart';
import '../../core/frigate/recordings.dart';
import '../../core/frigate/vod_proxy.dart';
import '../live/photo.dart';
import 'motion_passages.dart';

abstract final class ClipDefaults {
  /// Clip proposed outside a passage: this much on each side of the
  /// playhead.
  static const around = Duration(seconds: 15);

  /// Lengths offered in one touch, around the playhead.
  static const presets = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  /// Step of the start and end buttons.
  static const step = Duration(seconds: 10);

  /// Longest clip: about 5 MB a minute at 1080p; a setting comes with the
  /// 0.2 settings screen (decision 0002).
  static const maxLength = Duration(minutes: 10);

  /// Shortest clip.
  static const minLength = Duration(seconds: 2);

  /// Folder of the cache holding the last clip, kept for the share sheet.
  static const folder = 'clips';

  /// Frigate writes the clip as it reads the recording: a silence this
  /// long means it stopped.
  static const stall = Duration(seconds: 60);
}

/// A stretch of recording to export.
typedef ClipRange = ({DateTime start, DateTime end});

extension ClipRangeLength on ClipRange {
  Duration get length => end.difference(start);
}

/// The clip proposed at [playhead]: the passage being played when there is
/// one, otherwise [ClipDefaults.around] on each side; never past [liveEdge]
/// nor longer than [ClipDefaults.maxLength].
ClipRange defaultClipRange(
  DateTime playhead, {
  MotionPassage? passage,
  required DateTime liveEdge,
}) {
  if (passage != null) {
    return clampClip(
      (start: passage.start, end: passage.end),
      liveEdge: liveEdge,
    );
  }
  return clampClip(
    (
      start: playhead.subtract(ClipDefaults.around),
      end: playhead.add(ClipDefaults.around),
    ),
    liveEdge: liveEdge,
  );
}

/// [length] centred on [playhead], within the recording written.
ClipRange presetClip(
  DateTime playhead,
  Duration length, {
  required DateTime liveEdge,
}) {
  var end = playhead.add(length ~/ 2);
  if (end.isAfter(liveEdge)) end = liveEdge;
  return clampClip((start: end.subtract(length), end: end), liveEdge: liveEdge);
}

/// Keeps [range] before [liveEdge], at least [ClipDefaults.minLength] and at
/// most [ClipDefaults.maxLength] long; the start is kept when possible.
ClipRange clampClip(ClipRange range, {required DateTime liveEdge}) {
  var start = range.start;
  var end = range.end;
  if (end.isAfter(liveEdge)) end = liveEdge;
  if (end.difference(start) > ClipDefaults.maxLength) {
    end = start.add(ClipDefaults.maxLength);
  }
  if (end.difference(start) < ClipDefaults.minLength) {
    start = end.subtract(ClipDefaults.minLength);
  }
  return (start: start, end: end);
}

/// The download was stopped by the user.
class ClipCancelled implements Exception {
  const ClipCancelled();
}

/// Lets the screen stop a download.
class ClipCancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }
}

/// Path of Frigate's MP4 of a camera's recording between two times.
String clipPath(String camera, ClipRange range) =>
    '/api/${Uri.encodeComponent(camera)}/start/${epochSeconds(range.start)}'
    '/end/${epochSeconds(range.end)}/clip.mp4';

/// Downloads the clip of [camera] over [range] into `<cache>/clips`,
/// removing the clip kept before. [onProgress] gets the bytes received.
Future<File> downloadClip({
  required StreamOpener open,
  required String camera,
  required ClipRange range,
  required Directory cache,
  required String name,
  void Function(int bytes)? onProgress,
  ClipCancelToken? cancel,
}) async {
  final folder = Directory('${cache.path}/${ClipDefaults.folder}');
  if (folder.existsSync()) {
    for (final old in folder.listSync()) {
      old.deleteSync(recursive: true);
    }
  } else {
    folder.createSync(recursive: true);
  }
  final target = File('${folder.path}/$name.mp4');
  final partial = File('${target.path}.part');

  final response = await open(
    clipPath(camera, range),
    headers: const {'Accept': 'video/mp4'},
  );
  if (cancel?.cancelled ?? false) {
    unawaited(response.stream.listen(null).cancel());
    throw const ClipCancelled();
  }
  if (response.statusCode == 401 || response.statusCode == 403) {
    unawaited(response.stream.listen(null).cancel());
    throw const FrigateAuthException('Session expirée ou non autorisée.');
  }
  if (response.statusCode != 200) {
    unawaited(response.stream.listen(null).cancel());
    throw FrigateNetworkException('Extrait refusé (${response.statusCode})');
  }

  final sink = partial.openWrite();
  final done = Completer<void>();
  var received = 0;
  late final StreamSubscription<List<int>> subscription;
  void fail(Object error) {
    if (!done.isCompleted) done.completeError(error);
  }

  subscription = response.stream
      .timeout(
        ClipDefaults.stall,
        onTimeout: (sink) => sink.addError(
          const FrigateNetworkException('Frigate ne répond plus.'),
        ),
      )
      .listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received);
        },
        onError: (Object e) {
          unawaited(subscription.cancel());
          fail(
            e is FrigateNetworkException
                ? e
                : FrigateNetworkException('Connexion interrompue.', e),
          );
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
  cancel?._listeners.add(() {
    unawaited(subscription.cancel());
    fail(const ClipCancelled());
  });

  try {
    await done.future;
    await sink.close();
  } catch (_) {
    await sink.close().catchError((_) {});
    if (partial.existsSync()) partial.deleteSync();
    rethrow;
  }
  if (received == 0) {
    partial.deleteSync();
    throw const FrigateNetworkException('Aucun enregistrement à exporter.');
  }
  return partial.renameSync(target.path);
}

/// Saves or shares a clip; injected so screens can be tested without the
/// gallery or the share sheet.
abstract class VideoActions {
  Future<void> save(File mp4);
  Future<void> share(File mp4);
}

/// Gallery album and share sheet of the device.
class DeviceVideoActions implements VideoActions {
  const DeviceVideoActions();

  @override
  Future<void> save(File mp4) async {
    if (!await Gal.hasPermission(toAlbum: true)) {
      await Gal.requestPermission(toAlbum: true);
    }
    await Gal.putVideo(mp4.path, album: DevicePhotoActions.album);
  }

  @override
  Future<void> share(File mp4) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(mp4.path, mimeType: 'video/mp4')]),
    );
  }
}
