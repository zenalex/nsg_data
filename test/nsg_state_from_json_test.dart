// Состояние объекта при чтении из JSON (NSG-SOFT/futbolista-tasks#1602).
//
// Узкая выборка (neededFields) возвращала объекты без ключа `state`: на сервере она
// строит строки таблицы в памяти, а у них состояния нет. Клиент оставлял умолчание
// unknown, сервер выбирал INSERT/UPDATE по присланному состоянию и не делал ни того,
// ни другого — POST возвращал 200 и молча ничего не записывал.
//
// Серверную половину починили (NsgServerClasses#3), здесь — защита на клиенте:
// объект, приехавший из выдачи с заполненным идентификатором, считается прочитанным.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';

class StateTestItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'StateTestItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => StateTestItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

void main() {
  setUpAll(() {
    if (!NsgDataClient.client.isRegistered(StateTestItem)) {
      NsgDataClient.client.registerDataItem(
        StateTestItem(),
        remoteProvider: NsgDataProvider(
          applicationName: 'test',
          firebaseToken: '',
          applicationVersion: '1.0',
          availableServers: NsgServerParams(<String, String>{}, ''),
        ),
      );
    }
  });

  test('состояние берётся из ответа, когда сервер его прислал', () {
    final item = StateTestItem()
      ..fromJson({
        'id': 'd6b7a0f4-0000-0000-0000-000000000001',
        'name': 'Спартак',
        'state': NsgDataItemState.create.index,
        'docState': NsgDataItemDocState.handled.index,
      });

    expect(item.state, NsgDataItemState.create);
    expect(item.docState, NsgDataItemDocState.handled);
  });

  test('ответ без state, но с идентификатором — объект прочитан, а не создан', () {
    final item = StateTestItem()
      ..fromJson({
        'id': 'd6b7a0f4-0000-0000-0000-000000000001',
        'name': 'Спартак',
      });

    expect(item.state, NsgDataItemState.fill,
        reason: 'unknown заставит сервер молча не записать изменения (#1602)');
  });

  test('ответ без state и без идентификатора состояние не выдумывает', () {
    final item = StateTestItem()..fromJson({'name': 'Спартак'});

    expect(item.state, NsgDataItemState.unknown);
  });

  test('пустой идентификатор состояние не выдумывает', () {
    final item = StateTestItem()
      ..fromJson({'id': '00000000-0000-0000-0000-000000000000', 'name': 'Спартак'});

    expect(item.state, NsgDataItemState.unknown);
  });
}
