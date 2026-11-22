import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small settings of the app (decision 0002: every one has a default and is
/// never erased by an update), kept in the same secure storage as the
/// session so no extra dependency is needed.
class Preferences {
  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;

  Preferences([this._storage]) : _memory = null;

  /// In-memory settings for tests.
  Preferences.inMemory([Map<String, String>? initial])
    : _storage = null,
      _memory = initial ?? <String, String>{};

  FlutterSecureStorage get _secure => _storage ?? const FlutterSecureStorage();

  Future<String?> read(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key];
    try {
      return await _secure.read(key: key);
    } on Exception {
      return null;
    }
  }

  /// Writes [value], or removes the setting when it is `null`.
  Future<void> write(String key, String? value) async {
    final memory = _memory;
    if (memory != null) {
      if (value == null) {
        memory.remove(key);
      } else {
        memory[key] = value;
      }
      return;
    }
    try {
      if (value == null) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
    } on Exception {
      // A setting that cannot be saved keeps its default next time.
    }
  }
}
