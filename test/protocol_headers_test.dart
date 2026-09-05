import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

void main() {
  NsgDataProvider make({
    String schemaHash = '',
    String token = '',
    String applicationVersion = '0.0.0',
  }) {
    final p = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: applicationVersion,
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

    // Версия приложения нужна серверу на КАЖДОМ запросе: гейт функций
    // (ТребованияДляФункций) обязан судить по версии того клиента, который
    // прислал этот запрос, а не по копии, оставшейся с прошлого старта.
    test('X-Nsg-App-Version is sent with every request', () {
      expect(make(applicationVersion: '1.9.418').getAuthorizationHeader()['X-Nsg-App-Version'], '1.9.418');
      // И без токена тоже: анонимная сессия — такой же клиент со своей версией.
      final anonymous = make(applicationVersion: '1.9.418').getAuthorizationHeader();
      expect(anonymous.containsKey('Authorization'), isFalse);
      expect(anonymous['X-Nsg-App-Version'], '1.9.418');
    });

    test('X-Nsg-App-Version is omitted when applicationVersion is empty', () {
      // Пустой заголовок и отсутствие заголовка сервер трактует одинаково,
      // но слать пустоту незачем — это тот же приём, что у schemaHash.
      final h = make(applicationVersion: '').getAuthorizationHeader();
      expect(h.containsKey('X-Nsg-App-Version'), isFalse);
    });

    test('X-Nsg-App-Version is passed through verbatim, build suffix included', () {
      // Суффикс сборки срезает сервер; клиент не должен решать за него, что
      // именно «версия» — иначе две стороны режут по-разному.
      final h = make(applicationVersion: '1.9.419+190419').getAuthorizationHeader();
      expect(h['X-Nsg-App-Version'], '1.9.419+190419');
    });
  });
}
