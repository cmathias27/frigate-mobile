import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'release.dart';

abstract final class UpdateDefaults {
  /// The only address called outside the Frigate server (CLAUDE.md).
  static final latestRelease = Uri.parse(
    'https://api.github.com/repos/cmathias27/frigate-mobile/releases/latest',
  );

  /// Automatic check at most this often, at start-up.
  static const checkEvery = Duration(days: 1);

  /// A larger download is stopped.
  static const maxBytes = 300 * 1024 * 1024;

  /// Folder of the cache shared with Android's installer (update_paths.xml).
  static const folder = 'updates';
}

/// Why an update failed: `network`, `checksum`, `too_large`, `folder`,
/// `unsupported`, or from Android `package`, `version`, `signature`,
/// `install`.
class UpdateException implements Exception {
  final String code;
  const UpdateException(this.code);

  @override
  String toString() => 'UpdateException($code)';
}

/// What the phone does: its version, the permission to install apps, and
/// Android's installer.
abstract class UpdatePlatform {
  Future<String?> currentVersion();
  Future<Directory> cacheDirectory();
  Future<bool> canInstall();
  Future<void> openInstallSettings();

  /// Opens Android's installer on [apk]; throws [UpdateException] when the
  /// file is not this app, in [version], signed by the same key.
  Future<void> install(File apk, String version);
}

class AndroidUpdatePlatform implements UpdatePlatform {
  static const _channel = MethodChannel(
    'io.github.cmathias27.frigate_mobile/update',
  );

  @override
  Future<String?> currentVersion() async {
    try {
      return await _channel.invokeMethod<String>('version');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<Directory> cacheDirectory() => getTemporaryDirectory();

  @override
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // Nothing more can be done from here.
    }
  }

  @override
  Future<void> install(File apk, String version) async {
    final String? result;
    try {
      result = await _channel.invokeMethod<String>('install', {
        'path': apk.path,
        'version': version,
      });
    } on PlatformException {
      throw const UpdateException('install');
    }
    if (result != 'ok') throw UpdateException(result ?? 'install');
  }
}

/// Reads the latest release on GitHub and downloads its APK, checked
/// against the release's SHA256SUMS.
class UpdateService {
  final http.Client _client;
  final Uri latestRelease;
  final int maxBytes;

  UpdateService({http.Client? client, Uri? latestRelease, int? maxBytes})
    : _client = client ?? http.Client(),
      latestRelease = latestRelease ?? UpdateDefaults.latestRelease,
      maxBytes = maxBytes ?? UpdateDefaults.maxBytes;

  /// The latest published release, or `null` when there is none yet.
  Future<AppRelease?> latest() async {
    final http.Response response;
    try {
      response = await _client
          .get(
            latestRelease,
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
    } on Exception {
      throw const UpdateException('network');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw const UpdateException('network');
    try {
      return parseRelease(jsonDecode(response.body));
    } on FormatException {
      throw const UpdateException('network');
    }
  }

  /// Downloads the APK of [release] into `<cache>/updates`, removing older
  /// downloads, and returns it once its SHA-256 matches.
  Future<File> download(
    AppRelease release,
    Directory cache, {
    void Function(double? progress)? onProgress,
  }) async {
    if (!release.installable) throw const UpdateException('unsupported');
    final expected = await _expectedHash(release);

    final folder = Directory('${cache.path}/${UpdateDefaults.folder}');
    final target = File('${folder.path}/${release.apkName}');
    final partial = File('${target.path}.part');
    try {
      if (folder.existsSync()) {
        for (final old in folder.listSync()) {
          if (old.path != target.path) old.deleteSync(recursive: true);
        }
      } else {
        folder.createSync(recursive: true);
      }
      // Already downloaded and still intact.
      if (target.existsSync() && await _hash(target) == expected) {
        return target;
      }
    } on FileSystemException {
      throw const UpdateException('folder');
    }

    final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', release.apk!))
          .timeout(const Duration(seconds: 30));
    } on Exception {
      throw const UpdateException('network');
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>().catchError((_) {});
      throw const UpdateException('network');
    }
    final total = response.contentLength ?? release.apkSize;
    if (total != null && total > maxBytes) {
      await response.stream.drain<void>().catchError((_) {});
      throw const UpdateException('too_large');
    }

    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    IOSink? sink;
    var received = 0;
    try {
      sink = partial.openWrite();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        received += chunk.length;
        if (received > maxBytes) throw const UpdateException('too_large');
        hasher.add(chunk);
        sink.add(chunk);
        onProgress?.call(total == null || total == 0 ? null : received / total);
      }
      hasher.close();
      await sink.close();
    } catch (e) {
      await sink?.close().catchError((_) {});
      _deleteQuietly(partial);
      if (e is UpdateException) rethrow;
      if (e is FileSystemException) throw const UpdateException('folder');
      throw const UpdateException('network');
    }
    if (digest.value.toString() != expected) {
      _deleteQuietly(partial);
      throw const UpdateException('checksum');
    }
    try {
      return partial.renameSync(target.path);
    } on FileSystemException {
      throw const UpdateException('folder');
    }
  }

  Future<String> _expectedHash(AppRelease release) async {
    final http.Response sums;
    try {
      sums = await _client
          .get(release.sums!)
          .timeout(const Duration(seconds: 15));
    } on Exception {
      throw const UpdateException('network');
    }
    if (sums.statusCode != 200) throw const UpdateException('network');
    final expected = expectedSha256(sums.body, release.apkName!);
    if (expected == null) throw const UpdateException('checksum');
    return expected;
  }

  static Future<String> _hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Removed with the next download.
    }
  }

  void close() => _client.close();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
