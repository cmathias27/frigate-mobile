import 'package:crypto/crypto.dart';

import 'server_config.dart';

/// Decides whether a certificate refused by the system can still be trusted
/// (decision 0004, point 4).
///
/// Only the local address of the server may present a self-signed
/// certificate, and only the one whose SHA-256 fingerprint the user
/// confirmed. Any other host, port or certificate is refused; the remote
/// address always needs a certificate the system trusts.
class CertificateGuard {
  final ServerConfig config;

  /// Fingerprint of the last certificate refused on the local address,
  /// offered to the user for confirmation.
  String? rejected;

  CertificateGuard(this.config);

  /// `badCertificateCallback` of the HTTP client.
  bool accepts(List<int> der, String host, int port) {
    if (!config.allowSelfSignedCert) return false;
    final local = Uri.tryParse(config.localUrl);
    if (local == null || local.scheme != 'https') return false;
    if (host.toLowerCase() != local.host.toLowerCase() || port != local.port) {
      return false;
    }
    final fingerprint = fingerprintOf(der);
    if (fingerprint == config.certFingerprint) return true;
    rejected = fingerprint;
    return false;
  }

  /// Takes the fingerprint refused last, if any.
  String? takeRejected() {
    final value = rejected;
    rejected = null;
    return value;
  }

  /// SHA-256 of a DER certificate, upper-case hex pairs joined by colons,
  /// as `openssl x509 -fingerprint -sha256` prints it.
  static String fingerprintOf(List<int> der) => sha256
      .convert(der)
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
