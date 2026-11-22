import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../frigate/capabilities.dart';
import '../frigate/client.dart';
import '../frigate/server_config.dart';
import '../storage/session_storage.dart';

/// State of the active session with a Frigate server.
enum SessionStatus {
  /// App is starting and reading storage.
  initializing,

  /// No server configured or not authenticated.
  unauthenticated,

  /// Currently authenticating or loading capabilities.
  loading,

  /// Authenticated and ready.
  authenticated,

  /// Previously authenticated but connection failed (network offline, etc.).
  connectionError,
}

/// Coordinates server connection, authentication state and capabilities.
class SessionController extends ChangeNotifier {
  final SessionStorage _storage;
  final http.Client? httpClient;

  SessionStatus _status = SessionStatus.initializing;
  ServerConfig? _config;
  ServerCapabilities? _capabilities;
  FrigateClient? _client;
  String? _errorMessage;

  SessionController({SessionStorage? storage, this.httpClient})
    : _storage = storage ?? SessionStorage();

  SessionStatus get status => _status;
  ServerConfig? get config => _config;
  ServerCapabilities? get capabilities => _capabilities;
  FrigateClient? get client => _client;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == SessionStatus.authenticated;
  bool get isLoading => _status == SessionStatus.loading;

  /// Initializes the session from local storage on startup.
  Future<void> init() async {
    _status = SessionStatus.initializing;
    notifyListeners();

    try {
      final savedConfig = await _storage.loadServerConfig();
      final savedToken = await _storage.loadToken();

      if (savedConfig == null || savedToken == null || savedToken.isEmpty) {
        _config = savedConfig;
        _status = SessionStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _config = savedConfig;
      final c = FrigateClient(
        config: savedConfig,
        token: savedToken,
        client: httpClient,
      );
      _client = c;

      try {
        _capabilities = await c.fetchCapabilities();
        _status = SessionStatus.authenticated;
        _errorMessage = null;
      } on FrigateAuthException {
        // Token expired or invalidated on server.
        await _storage.clearSession();
        _client = null;
        _status = SessionStatus.unauthenticated;
        _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
      } on FrigateNetworkException catch (e) {
        // Server unreachable: keep the client and notify error.
        _status = SessionStatus.connectionError;
        _errorMessage = e.message;
      }
    } catch (e) {
      _status = SessionStatus.unauthenticated;
      _errorMessage = 'Erreur d\'initialisation: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Logs into the specified server and loads its capabilities.
  Future<bool> login({
    required ServerConfig config,
    required String password,
  }) async {
    _status = SessionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final c = FrigateClient(config: config, client: httpClient);
    try {
      final token = await c.login(password);
      final caps = await c.fetchCapabilities();

      _config = config;
      _client = c;
      _capabilities = caps;
      _status = SessionStatus.authenticated;
      _errorMessage = null;

      await _storage.saveServerConfig(config);
      await _storage.saveToken(token);
      notifyListeners();
      return true;
    } on FrigateAuthException catch (e) {
      c.close();
      _status = SessionStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on FrigateNetworkException catch (e) {
      c.close();
      _status = SessionStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      c.close();
      _status = SessionStatus.unauthenticated;
      _errorMessage = 'Erreur inattendue: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reloads server capabilities (e.g. after camera or settings update).
  Future<void> refreshCapabilities() async {
    final c = _client;
    if (c == null) return;
    try {
      _capabilities = await c.fetchCapabilities();
      _status = SessionStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Impossible de rafraîchir les données: $e';
      notifyListeners();
    }
  }

  /// Called when the server refuses the token during use (expired or
  /// revoked): back to the login screen, keeping the server settings.
  Future<void> sessionExpired() async {
    if (_status != SessionStatus.authenticated) return;
    _client?.close();
    _client = null;
    _capabilities = null;
    _status = SessionStatus.unauthenticated;
    _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
    await _storage.clearSession();
    notifyListeners();
  }

  /// Disconnects the active session and clears the saved token.
  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _capabilities = null;
    _status = SessionStatus.unauthenticated;
    _errorMessage = null;
    await _storage.clearSession();
    notifyListeners();
  }

  /// Deletes the saved server configuration and disconnects.
  Future<void> deleteServer() async {
    _client?.close();
    _client = null;
    _capabilities = null;
    _config = null;
    _status = SessionStatus.unauthenticated;
    _errorMessage = null;
    await _storage.clearAll();
    notifyListeners();
  }
}
