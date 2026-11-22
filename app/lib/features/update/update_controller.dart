import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/storage/preferences.dart';
import 'release.dart';
import 'update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  failed,
}

/// In-app update (decision 0003): the check, at most once a day at
/// start-up and on demand, can be turned off; the APK is checked before
/// Android's installer opens.
class UpdateController extends ChangeNotifier {
  static const _keyAutoCheck = 'fm_update_auto_check';
  static const _keyLastCheck = 'fm_update_last_check';
  static const _keySeenVersion = 'fm_update_seen_version';

  final UpdateService _service;
  final UpdatePlatform _platform;
  final Preferences _preferences;
  final DateTime Function() _clock;

  String? _currentVersion;
  bool _autoCheck = true;
  UpdateStatus _status = UpdateStatus.idle;
  AppRelease? _release;
  double? _progress;
  String? _error;
  bool _busy = false;

  UpdateController({
    required this._service,
    required this._platform,
    required this._preferences,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  String? get currentVersion => _currentVersion;
  bool get autoCheck => _autoCheck;
  UpdateStatus get status => _status;
  AppRelease? get release => _release;

  /// Share of the APK downloaded, `null` when unknown.
  double? get progress => _progress;

  /// Code of the last failure ([UpdateException.code]).
  String? get error => _error;

  Future<void> init() async {
    _currentVersion = await _platform.currentVersion();
    _autoCheck = await _preferences.read(_keyAutoCheck) != 'false';
    notifyListeners();
  }

  Future<void> setAutoCheck(bool value) async {
    _autoCheck = value;
    notifyListeners();
    await _preferences.write(_keyAutoCheck, value ? null : 'false');
  }

  /// True once per new version installed over an older one: the app then
  /// shows its notes ("Nouveautés"). A first installation shows nothing.
  Future<bool> takeWhatsNew() async {
    final current = _currentVersion;
    if (current == null) return false;
    final seen = await _preferences.read(_keySeenVersion);
    if (seen == current) return false;
    await _preferences.write(_keySeenVersion, current);
    return seen != null && isNewer(current, seen);
  }

  /// The automatic check: when allowed and not done for a day. Returns the
  /// newer release found, if any; a failure stays silent.
  Future<AppRelease?> checkOnStartup() async {
    if (!_autoCheck) return null;
    final last = DateTime.tryParse(
      await _preferences.read(_keyLastCheck) ?? '',
    );
    final now = _clock();
    if (last != null &&
        now.difference(last) < UpdateDefaults.checkEvery &&
        !now.isBefore(last)) {
      return null;
    }
    await check();
    return _status == UpdateStatus.available ? _release : null;
  }

  /// Asks GitHub for the latest release.
  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    _status = UpdateStatus.checking;
    _error = null;
    notifyListeners();
    try {
      final release = await _service.latest();
      await _preferences.write(_keyLastCheck, _clock().toIso8601String());
      if (release != null && isNewer(release.version, _currentVersion)) {
        _release = release;
        _status = UpdateStatus.available;
      } else {
        _status = UpdateStatus.upToDate;
      }
    } on UpdateException catch (e) {
      _fail(e.code);
    } finally {
      _busy = false;
    }
    notifyListeners();
  }

  /// Downloads and checks the APK, then opens Android's installer.
  ///
  /// Returns `false` when the permission to install apps is missing: the
  /// screen explains it, then calls [openInstallSettings].
  Future<bool> install() async {
    final release = _release;
    if (release == null || _busy) return true;
    if (!await _platform.canInstall()) return false;
    _busy = true;
    _status = UpdateStatus.downloading;
    _progress = null;
    _error = null;
    notifyListeners();
    try {
      final File apk = await _service.download(
        release,
        await _platform.cacheDirectory(),
        onProgress: (progress) {
          _progress = progress;
          notifyListeners();
        },
      );
      await _platform.install(apk, release.version);
      _status = UpdateStatus.available;
    } on UpdateException catch (e) {
      _fail(e.code);
    } on FileSystemException {
      _fail('folder');
    } finally {
      _busy = false;
    }
    notifyListeners();
    return true;
  }

  Future<void> openInstallSettings() => _platform.openInstallSettings();

  void _fail(String code) {
    _status = UpdateStatus.failed;
    _error = code;
  }
}
