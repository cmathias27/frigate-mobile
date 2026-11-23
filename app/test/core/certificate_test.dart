import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/certificate_guard.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const der = [1, 2, 3];
  final fingerprint = CertificateGuard.fingerprintOf(der);
  const local = ServerConfig(
    name: 'Maison',
    localUrl: 'https://192.168.1.10:8971',
    remoteUrl: 'https://frigate.example.com',
    username: 'viewer',
  );

  group('CertificateGuard', () {
    test('fingerprint is printed like openssl', () {
      expect(fingerprint, matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')));
    });

    test('accepts only the confirmed certificate of the local address', () {
      final guard = CertificateGuard(
        local.copyWith(certFingerprint: fingerprint),
      );
      expect(guard.accepts(der, '192.168.1.10', 8971), isTrue);
      expect(guard.rejected, isNull);
      // Same certificate elsewhere: another host, another port, the remote.
      expect(guard.accepts(der, '192.168.1.11', 8971), isFalse);
      expect(guard.accepts(der, '192.168.1.10', 443), isFalse);
      expect(guard.accepts(der, 'frigate.example.com', 443), isFalse);
      // Another certificate on the local address is kept for confirmation.
      expect(guard.accepts([9], '192.168.1.10', 8971), isFalse);
      expect(guard.takeRejected(), CertificateGuard.fingerprintOf([9]));
      expect(guard.rejected, isNull);
    });

    test('without confirmation, nothing is accepted', () {
      final guard = CertificateGuard(local);
      expect(guard.accepts(der, '192.168.1.10', 8971), isFalse);
      expect(guard.rejected, fingerprint);
    });

    test('nothing at all when self-signed certificates are refused', () {
      final guard = CertificateGuard(
        local.copyWith(
          allowSelfSignedCert: false,
          certFingerprint: fingerprint,
        ),
      );
      expect(guard.accepts(der, '192.168.1.10', 8971), isFalse);
      expect(guard.rejected, isNull);
    });
  });

  group('FrigateClient and certificates', () {
    /// The local address presents an unconfirmed certificate; the remote
    /// one answers when [remoteUp].
    FrigateClient clientWith({
      required ServerConfig config,
      bool remoteUp = false,
    }) {
      late FrigateClient client;
      client = FrigateClient(
        config: config,
        client: MockClient((request) async {
          if (request.url.host == '192.168.1.10') {
            // What the HTTP client's callback does before refusing.
            client.certificates.accepts([7], '192.168.1.10', 8971);
            throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
          }
          if (!remoteUp) {
            throw http.ClientException('unreachable', request.url);
          }
          return http.Response(
            '',
            200,
            headers: {'set-cookie': 'frigate_token=jwt; Path=/'},
          );
        }),
      );
      return client;
    }

    test('an unconfirmed certificate asks for confirmation', () async {
      final client = clientWith(
        config: const ServerConfig(
          name: 'Maison',
          localUrl: 'https://192.168.1.10:8971',
          username: 'viewer',
        ),
      );
      await expectLater(
        client.login('secret'),
        throwsA(
          isA<FrigateCertificateException>()
              .having(
                (e) => e.fingerprint,
                'fingerprint',
                CertificateGuard.fingerprintOf([7]),
              )
              .having((e) => e.changed, 'changed', isFalse),
        ),
      );
    });

    test('a changed certificate is reported as such', () async {
      final client = clientWith(
        config: local.copyWith(certFingerprint: fingerprint),
      );
      await expectLater(
        client.login('secret'),
        throwsA(
          isA<FrigateCertificateException>().having(
            (e) => e.changed,
            'changed',
            isTrue,
          ),
        ),
      );
    });

    test('the remote address is used when it answers', () async {
      final client = clientWith(config: local, remoteUp: true);
      expect(await client.login('secret'), 'jwt');
      expect(client.usingRemote, isTrue);
    });

    test('the probe of the local address carries no session', () async {
      final headers = <Map<String, String>>[];
      final client = FrigateClient(
        config: local,
        token: 'jwt',
        client: MockClient((request) async {
          headers.add(request.headers);
          return http.Response('0.18.0', 200);
        }),
      );
      await client.resolveAddress();
      expect(headers.single.containsKey('Authorization'), isFalse);
      expect(headers.single.containsKey('Cookie'), isFalse);
    });
  });
}
