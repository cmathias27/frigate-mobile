import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../frigate/server_config.dart';

/// Persists server configuration and session tokens in device secure storage
/// (decision 0004).
///
/// On Android, this uses Android Keystore / EncryptedSharedPreferences.
/// Unit tests can inject an in-memory map or mock storage.
class SessionStorage {
  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memoryFallback;

  static const _keyServerConfig = 'fm_server_config';
  static const _keyToken = 'fm_session_token';

  SessionStorage([this._storage]) : _memoryFallback = null;

  /// Creates an in-memory storage for unit tests.
  SessionStorage.inMemory([Map<String, String>? initialData])
    : _storage = null,
      _memoryFallback = initialData ?? <String, String>{};

  FlutterSecureStorage get _secureStorage =>
      _storage ?? const FlutterSecureStorage();

  /// Saves the active server configuration.
  Future<void> saveServerConfig(ServerConfig config) async {
    if (_memoryFallback != null) {
      _memoryFallback[_keyServerConfig] = config.encode();
      return;
    }
    await _secureStorage.write(key: _keyServerConfig, value: config.encode());
  }

  /// Loads the active server configuration, or null if none is saved.
  Future<ServerConfig?> loadServerConfig() async {
    final String? raw;
    if (_memoryFallback != null) {
      raw = _memoryFallback[_keyServerConfig];
    } else {
      raw = await _secureStorage.read(key: _keyServerConfig);
    }
    return ServerConfig.decode(raw);
  }

  /// Saves the session authentication token.
  Future<void> saveToken(String token) async {
    if (_memoryFallback != null) {
      _memoryFallback[_keyToken] = token;
      return;
    }
    await _secureStorage.write(key: _keyToken, value: token);
  }

  /// Loads the stored session token, or null if not logged in.
  Future<String?> loadToken() async {
    if (_memoryFallback != null) {
      return _memoryFallback[_keyToken];
    }
    return _secureStorage.read(key: _keyToken);
  }

  /// Clears stored token and session, disconnecting the user.
  /// Server configuration is preserved so the user can easily reconnect.
  Future<void> clearSession() async {
    if (_memoryFallback != null) {
      _memoryFallback.remove(_keyToken);
      return;
    }
    await _secureStorage.delete(key: _keyToken);
  }

  /// Clears both configuration and session (full reset / server deletion).
  Future<void> clearAll() async {
    if (_memoryFallback != null) {
      _memoryFallback.clear();
      return;
    }
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyServerConfig);
  }
}
