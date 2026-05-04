import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

void main() {
  NsgDataProvider make({String schemaHash = '', String token = ''}) {
    final p = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '0.0.0',
      availableServers: NsgServerParams({}, ''),
      schemaHash: schemaHash,
    );
    if (token.isNotEmpty) p.token = token;
    return p;
  }

  group('NsgDataProvider.getAuthorizationHeader', () {
    test('protocolVersion is library-level constant equal to 1', () {
      expect(NsgDataProvider.protocolVersion, 1);
    });

    test('X-Nsg-Protocol-Version is always present', () {
      expect(make().getAuthorizationHeader()['X-Nsg-Protocol-Version'], '1');
      expect(
        make(schemaHash: 'abc', token: 't').getAuthorizationHeader()['X-Nsg-Protocol-Version'],
        '1',
      );
    });

    test('X-Nsg-Schema-Hash is omitted when schemaHash is empty', () {
      final h = make().getAuthorizationHeader();
      expect(h.containsKey('X-Nsg-Schema-Hash'), isFalse);
    });

    test('X-Nsg-Schema-Hash is included when schemaHash is non-empty', () {
      final h = make(schemaHash: 'deadbeefcafef00d').getAuthorizationHeader();
      expect(h['X-Nsg-Schema-Hash'], 'deadbeefcafef00d');
    });

    test('Authorization is omitted when token is empty', () {
      final h = make().getAuthorizationHeader();
      expect(h.containsKey('Authorization'), isFalse);
    });

    test('Authorization is included when token is set', () {
      final h = make(token: 'tok123').getAuthorizationHeader();
      expect(h['Authorization'], 'tok123');
    });
  });
}
