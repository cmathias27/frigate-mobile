import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';

void main() {
  test('normalizeUrl handles trailing slashes and missing scheme', () {
    expect(
      ServerConfig.normalizeUrl('192.168.1.10:8971/'),
      'https://192.168.1.10:8971',
    );
    expect(
      ServerConfig.normalizeUrl('http://192.168.1.10:5000///'),
      'http://192.168.1.10:5000',
    );
    expect(
      ServerConfig.normalizeUrl('https://frigate.example.com'),
      'https://frigate.example.com',
    );
  });

  test('addressProblem refuses clear text and the unauthenticated port', () {
    expect(ServerConfig.addressProblem('192.168.1.10:8971'), isNull);
    expect(ServerConfig.addressProblem('https://frigate.example.com'), isNull);
    expect(
      ServerConfig.addressProblem('http://192.168.1.10:8971'),
      AddressProblem.notHttps,
    );
    expect(
      ServerConfig.addressProblem('https://192.168.1.10:5000'),
      AddressProblem.unauthenticated,
    );
    expect(ServerConfig.addressProblem(''), AddressProblem.invalid);
  });

  test('encode and decode roundtrips faithfully', () {
    const config = ServerConfig(
      name: 'Maison',
      localUrl: 'https://192.168.1.10:8971',
      remoteUrl: 'https://frigate.example.com',
      username: 'admin',
      allowSelfSignedCert: true,
      certFingerprint: 'AB:CD',
    );

    final encoded = config.encode();
    final decoded = ServerConfig.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.name, 'Maison');
    expect(decoded.localUrl, 'https://192.168.1.10:8971');
    expect(decoded.remoteUrl, 'https://frigate.example.com');
    expect(decoded.username, 'admin');
    expect(decoded.allowSelfSignedCert, isTrue);
    expect(decoded.certFingerprint, 'AB:CD');
  });

  test('decode returns null on invalid or empty json', () {
    expect(ServerConfig.decode(null), isNull);
    expect(ServerConfig.decode(''), isNull);
    expect(ServerConfig.decode('not a json'), isNull);
    expect(ServerConfig.decode('[]'), isNull);
  });
}
