import 'dart:convert';

/// Configuration of a Frigate server to connect to (decision 0004).
///
/// Holds both the local and remote addresses, user credentials, and TLS
/// preferences. Passwords and session tokens are never stored here: they are
/// stored separately in secure storage.
class ServerConfig {
  /// User-defined label for the server (e.g. "Maison").
  final String name;

  /// Address on the local network, typically with port 8971
  /// (e.g. "https://192.168.1.10:8971").
  final String localUrl;

  /// Address reachable from outside (e.g. "https://frigate.example.com"),
  /// optional until remote access is configured.
  final String? remoteUrl;

  /// Frigate username (e.g. "admin").
  final String username;

  /// Accept a self-signed certificate on the local address, once its
  /// fingerprint is confirmed (decision 0004). Never for the remote address,
  /// which always requires a valid certificate.
  final bool allowSelfSignedCert;

  /// SHA-256 fingerprint of the self-signed certificate of the local
  /// address confirmed by the user (see `CertificateGuard`).
  final String? certFingerprint;

  const ServerConfig({
    required this.name,
    required this.localUrl,
    this.remoteUrl,
    required this.username,
    this.allowSelfSignedCert = true,
    this.certFingerprint,
  });

  /// Frigate's unauthenticated port, never used by the app (decision 0004).
  static const unauthenticatedPort = 5000;

  /// Why [raw] cannot be a server address, or null when it can.
  static AddressProblem? addressProblem(String raw) {
    final uri = Uri.tryParse(normalizeUrl(raw));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return AddressProblem.invalid;
    }
    if (uri.scheme != 'https') return AddressProblem.notHttps;
    if (uri.port == unauthenticatedPort) return AddressProblem.unauthenticated;
    return null;
  }

  /// Normalizes a URL: strips trailing slashes and ensures scheme.
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'localUrl': localUrl,
    if (remoteUrl != null && remoteUrl!.isNotEmpty) 'remoteUrl': remoteUrl,
    'username': username,
    'allowSelfSignedCert': allowSelfSignedCert,
    if (certFingerprint != null) 'certFingerprint': certFingerprint,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      name: json['name'] as String? ?? 'Frigate',
      localUrl: normalizeUrl(json['localUrl'] as String? ?? ''),
      remoteUrl:
          json['remoteUrl'] is String &&
              (json['remoteUrl'] as String).trim().isNotEmpty
          ? normalizeUrl(json['remoteUrl'] as String)
          : null,
      username: json['username'] as String? ?? '',
      allowSelfSignedCert: json['allowSelfSignedCert'] as bool? ?? true,
      certFingerprint: json['certFingerprint'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static ServerConfig? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return ServerConfig.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  ServerConfig copyWith({
    String? name,
    String? localUrl,
    String? remoteUrl,
    String? username,
    bool? allowSelfSignedCert,
    String? certFingerprint,
  }) {
    return ServerConfig(
      name: name ?? this.name,
      localUrl: localUrl != null ? normalizeUrl(localUrl) : this.localUrl,
      remoteUrl: remoteUrl != null ? normalizeUrl(remoteUrl) : this.remoteUrl,
      username: username ?? this.username,
      allowSelfSignedCert: allowSelfSignedCert ?? this.allowSelfSignedCert,
      certFingerprint: certFingerprint ?? this.certFingerprint,
    );
  }
}

/// Reasons a typed address is refused on the login screen.
enum AddressProblem {
  /// Not a URL with a host.
  invalid,

  /// `http://`: password and token would travel in clear.
  notHttps,

  /// Frigate's port 5000, without authentication (decision 0004).
  unauthenticated,
}
