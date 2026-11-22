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

  /// Accept self-signed certificates on the local address (decision 0004).
  /// Ignored for remote addresses, which always require valid certificates.
  final bool allowSelfSignedCert;

  const ServerConfig({
    required this.name,
    required this.localUrl,
    this.remoteUrl,
    required this.username,
    this.allowSelfSignedCert = true,
  });

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

  /// Returns whether a URL looks like a local network address (private IP,
  /// localhost, .local).
  static bool isLocalAddress(String urlString) {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    if (host.endsWith('.local')) return true;
    // Private IPv4 ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16.
    final parts = host.split('.');
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      if (octets.every((o) => o != null && o >= 0 && o <= 255)) {
        final a = octets[0]!;
        final b = octets[1]!;
        if (a == 10) return true;
        if (a == 172 && b >= 16 && b <= 31) return true;
        if (a == 192 && b == 168) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'localUrl': localUrl,
    if (remoteUrl != null && remoteUrl!.isNotEmpty) 'remoteUrl': remoteUrl,
    'username': username,
    'allowSelfSignedCert': allowSelfSignedCert,
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
  }) {
    return ServerConfig(
      name: name ?? this.name,
      localUrl: localUrl != null ? normalizeUrl(localUrl) : this.localUrl,
      remoteUrl: remoteUrl != null ? normalizeUrl(remoteUrl) : this.remoteUrl,
      username: username ?? this.username,
      allowSelfSignedCert: allowSelfSignedCert ?? this.allowSelfSignedCert,
    );
  }
}
