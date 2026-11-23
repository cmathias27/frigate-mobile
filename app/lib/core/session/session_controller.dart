import 'dart:async';
import 'dart:io';

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

/// Why the session could not be opened or kept, shown translated by the
/// screens; the technical cause goes to the logs only.
enum SessionError {
  /// The username or the password was refused at login.
  badCredentials,

  /// Frigate refuses logins for a while after too many failures.
  tooManyAttempts,

  /// Frigate answered the login with an unexpected status.
  serverError,

  /// No route to the server, connection refused or lost.
  unreachable,

  /// The server did not answer in time.
  timeout,

  /// The certificate was refused (changed, or self-signed on the remote
  /// address).
  certificate,

  /// The server answered something that is not Frigate's API.
  invalidResponse,

  /// The saved session is no longer accepted by Frigate.
  sessionExpired,

  /// Anything else.
  unexpected;

  /// The error for [e], raised during login when [login] is true.
  static SessionError of(Object e, {bool login = false}) => switch (e) {
    FrigateAuthException(statusCode: 401) =>
      login ? badCredentials : sessionExpired,
    FrigateAuthException(statusCode: 429) => tooManyAttempts,
    FrigateAuthException() => login ? serverError : sessionExpired,
    FrigateCertificateException() => certificate,
    FrigateUnreachableException(cause: TimeoutException()) => timeout,
    FrigateUnreachableException(cause: HandshakeException()) => certificate,
    FrigateUnreachableException() => unreachable,
    FrigateNetworkException() => invalidResponse,
    _ => unexpected,
  };
}

/// Coordinates server connection, authentication state and capabilities.
class SessionController extends ChangeNotifier {
  final SessionStorage _storage;
  final http.Client? httpClient;

  SessionStatus _status = SessionStatus.initializing;
  ServerConfig? _config;
  ServerCapabilities? _capabilities;
  FrigateClient? _client;
  SessionError? _error;
  FrigateCertificateException? _pendingCertificate;

  SessionController({SessionStorage? storage, this.httpClient})
    : _storage = storage ?? SessionStorage();

  /// After a failed [login]: the self-signed certificate of the local
  /// address, to confirm before logging in again (decision 0004).
  FrigateCertificateException? get pendingCertificate => _pendingCertificate;

  SessionStatus get status => _status;
  ServerConfig? get config => _config;
  ServerCapabilities? get capabilities => _capabilities;
  FrigateClient? get client => _client;

  /// Why the last login, start or refresh failed; `null` after a success.
  SessionError? get error => _error;

  void _fail(Object e, {bool login = false}) {
    debugPrint('Session: $e');
    _error = SessionError.of(e, login: login);
  }

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
      c.onAddressChanged = _onAddressChanged;

      try {
        await c.resolveAddress();
        _capabilities = await c.fetchCapabilities();
        _status = SessionStatus.authenticated;
        _error = null;
      } on FrigateAuthException {
        // Token expired or invalidated on server.
        await _expire();
      } on FrigateNetworkException catch (e) {
        // Server unreachable: keep the client, the login screen offers to
        // try again.
        _status = SessionStatus.connectionError;
        _fail(e);
      }
    } catch (e) {
      _status = SessionStatus.unauthenticated;
      _fail(e);
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
    _error = null;
    _pendingCertificate = null;
    notifyListeners();

    final c = FrigateClient(config: config, client: httpClient);
    try {
      await c.resolveAddress();
      final token = await c.login(password);
      c.onAddressChanged = _onAddressChanged;
      final caps = await c.fetchCapabilities();

      // The client kept after a failed start is replaced.
      _client?.close();
      _config = config;
      _client = c;
      _capabilities = caps;
      _status = SessionStatus.authenticated;
      _error = null;

      await _storage.saveServerConfig(config);
      await _storage.saveToken(token);
      notifyListeners();
      return true;
    } on FrigateCertificateException catch (e) {
      // The login screen asks the user to confirm the fingerprint.
      c.close();
      _status = SessionStatus.unauthenticated;
      _pendingCertificate = e;
      notifyListeners();
      return false;
    } catch (e) {
      c.close();
      _status = SessionStatus.unauthenticated;
      _fail(e, login: true);
      notifyListeners();
      return false;
    }
  }

  void _onAddressChanged(String url) => notifyListeners();

  /// Back from the background, possibly on another network: picks the
  /// local or the remote address again, and reloads after a failure.
  Future<void> resumed() async {
    if (_status == SessionStatus.connectionError) {
      await retry();
    } else {
      await _client?.resolveAddress();
    }
  }

  /// After a failed start: tries the saved session again, on whichever
  /// address answers now.
  Future<bool> retry() async {
    final c = _client;
    if (c == null) return false;
    _status = SessionStatus.loading;
    notifyListeners();
    await c.resolveAddress();
    final ok = await refreshCapabilities();
    if (!ok && _status == SessionStatus.loading) {
      _status = SessionStatus.connectionError;
      notifyListeners();
    }
    return ok;
  }

  /// Reloads server capabilities (e.g. after camera or settings update);
  /// returns whether they could be read, [error] says why not.
  Future<bool> refreshCapabilities() async {
    final c = _client;
    if (c == null) return false;
    try {
      _capabilities = await c.fetchCapabilities();
      _status = SessionStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    } on FrigateAuthException {
      await _expire();
      notifyListeners();
      return false;
    } catch (e) {
      _fail(e);
      notifyListeners();
      return false;
    }
  }

  /// Called when the server refuses the token during use (expired or
  /// revoked): back to the login screen, keeping the server settings.
  Future<void> sessionExpired() async {
    if (_status != SessionStatus.authenticated) return;
    await _expire();
    notifyListeners();
  }

  /// Back to the login screen, saying why, the server settings kept.
  Future<void> _expire() async {
    _client?.close();
    _client = null;
    _capabilities = null;
    _status = SessionStatus.unauthenticated;
    _error = SessionError.sessionExpired;
    await _storage.clearSession();
  }

  /// Disconnects the active session and clears the saved token.
  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _capabilities = null;
    _status = SessionStatus.unauthenticated;
    _error = null;
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
    _error = null;
    await _storage.clearAll();
    notifyListeners();
  }
}
