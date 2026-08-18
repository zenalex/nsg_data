// Обращение к незарегистрированному типу должно называть тип (#1557, GT-4134).
//
// Раньше в getNewObjectByTypeName стоял `assert` + `_registeredItems[typeName]!`.
// В релизе assert вырезан, оставался голый `!` — и в GlitchTip прилетало
// `Null check operator used on a null value` без единого намёка, какой тип не
// нашёлся. Такие события неотличимы ни друг от друга, ни от любого другого `!`
// в пакете, поэтому разбор каждый раз начинался с чтения стека вручную.
//
// Здесь закреплено то, ради чего правка делалась: тип назван, и по счётчику
// зарегистрированных типов видно, какой из двух диагнозов перед нами —
// «регистрация ещё не прошла» (0) или «потерян конкретный тип» (не 0).

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class Registered extends NsgDataItem {
  static const nameId = 'id';

  @override
  String get typeName => 'RegisteredServerName';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
  }

  @override
  NsgDataItem getNewObject() => Registered();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

void main() {
  group('незарегистрированный тип', () {
    test('сообщение называет тип и отличает «регистрация не прошла» от «потерян тип»', () {
      // Реестр — статический синглтон, в свежем изоляте он пуст. Это состояние
      // холодного старта: биндинг маршрута спросил тип до конца регистрации.
      expect(NsgDataClient.client.registeredDataItemsCount, 0);

      Object? empty;
      try {
        NsgDataClient.client.getNewObjectByTypeName('MatchItem');
      } catch (e) {
        empty = e;
      }
      expect(empty, isA<ArgumentError>());
      expect(empty.toString(), contains('MatchItem'));
      expect(empty.toString(), contains('registered types: 0'));

      // А теперь реестр не пуст — значит потерян именно запрошенный тип.
      NsgDataClient.client.registerDataItem(Registered());

      Object? missing;
      try {
        NsgDataClient.client.getNewObjectByTypeName('MatchItem');
      } catch (e) {
        missing = e;
      }
      expect(missing, isA<ArgumentError>());
      expect(missing.toString(), contains('MatchItem'));
      expect(missing.toString(), isNot(contains('registered types: 0')));
    });

    test('зарегистрированный тип по-прежнему отдаёт новый объект', () {
      expect(NsgDataClient.client.getNewObject(Registered), isA<Registered>());
      expect(NsgDataClient.client.getTypeByName('Registered'), Registered);
      expect(NsgDataClient.client.getTypeByServerName('RegisteredServerName'), Registered);
    });

    test('getTypeByName и getTypeByServerName тоже называют тип', () {
      expect(
        () => NsgDataClient.client.getTypeByName('MatchItem'),
        throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('MatchItem'))),
      );
      // Здесь промах в карте серверных имён — раньше он падал на том же `!`,
      // только через _registeredServerNames[typeName] == null.
      expect(
        () => NsgDataClient.client.getTypeByServerName('UnknownServerName'),
        throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('UnknownServerName'))),
      );
    });
  });
}
