import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/server_config.dart';

void main() {
  test('normalizeUrl handles trailing slashes and missing scheme', () {
    expect(
      ServerConfig.normalizeUrl('192.168.1.53:8971/'),
      'https://192.168.1.53:8971',
    );
    expect(
      ServerConfig.normalizeUrl('http://192.168.1.53:5000///'),
      'http://192.168.1.53:5000',
    );
    expect(
      ServerConfig.normalizeUrl('https://frigate.example.com'),
      'https://frigate.example.com',
    );
  });

  test('isLocalAddress detects private ranges and localhost', () {
    expect(ServerConfig.isLocalAddress('https://localhost:8971'), isTrue);
    expect(ServerConfig.isLocalAddress('https://127.0.0.1:8971'), isTrue);
    expect(ServerConfig.isLocalAddress('https://192.168.1.53:8971'), isTrue);
    expect(ServerConfig.isLocalAddress('https://10.0.0.5:8971'), isTrue);
    expect(ServerConfig.isLocalAddress('https://172.20.0.2:8971'), isTrue);
    expect(ServerConfig.isLocalAddress('https://frigate.local:8971'), isTrue);

    expect(ServerConfig.isLocalAddress('https://frigate.example.com'), isFalse);
    expect(ServerConfig.isLocalAddress('https://8.8.8.8'), isFalse);
  });

  test('encode and decode roundtrips faithfully', () {
    const config = ServerConfig(
      name: 'Maison',
      localUrl: 'https://192.168.1.53:8971',
      remoteUrl: 'https://frigate.example.com',
      username: 'admin',
      allowSelfSignedCert: true,
    );

    final encoded = config.encode();
    final decoded = ServerConfig.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.name, 'Maison');
    expect(decoded.localUrl, 'https://192.168.1.53:8971');
    expect(decoded.remoteUrl, 'https://frigate.example.com');
    expect(decoded.username, 'admin');
    expect(decoded.allowSelfSignedCert, isTrue);
  });

  test('decode returns null on invalid or empty json', () {
    expect(ServerConfig.decode(null), isNull);
    expect(ServerConfig.decode(''), isNull);
    expect(ServerConfig.decode('not a json'), isNull);
    expect(ServerConfig.decode('[]'), isNull);
  });
}
