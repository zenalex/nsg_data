// Контроллер табличной части не трогает незагруженную таблицу (#1394).
//
// Зачем: NsgDataTableController привязан к мастеру и перечитывает свою таблицу
// на каждую смену его текущего элемента. Когда мастера читают узко — а после
// оптимизации старта именно так и происходит, — таблицы в нём нет, и контроллер
// поднимал диагностический сигнал «обращение к незагруженной таблице» на ровном
// месте. Сигнал, который срабатывает всегда, перестают читать.
//
// Обратная сторона важнее: спрятать строки, которые пользователь только что
// добавил на клиенте, нельзя. Поэтому проверяются оба случая.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';

class TableRow_ extends NsgDataItem {
  static const nameId = 'id';
  static const nameText = 'text';

  @override
  String get typeName => 'TableRow_';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId), primaryKey: false);
    addField(NsgDataStringField(nameText), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TableRow_();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);
}

class TableOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameRows = 'rows';

  @override
  String get typeName => 'TableOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceListField<TableRow_>(nameRows), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TableOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<TableRow_> get rows => NsgDataTable<TableRow_>(owner: this, fieldName: nameRows);
}

void main() {
  setUpAll(() {
    final provider = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '1.0',
      availableServers: NsgServerParams(<String, String>{}, ''),
      newTableLogic: true,
    );
    for (final item in <NsgDataItem>[TableOwner(), TableRow_()]) {
      if (!NsgDataClient.client.isRegistered(item.runtimeType)) {
        NsgDataClient.client.registerDataItem(item, remoteProvider: provider);
      }
    }
  });

  group('незагруженная табличная часть', () {
    test('чтение узкого объекта не помечает таблицу загруженной', () {
      final owner = TableOwner()..id = 'O1';
      expect(owner.isTableLoaded(TableOwner.nameRows), isFalse,
          reason: 'таблицу никто не читал — значит «не загружена», а не «пуста»');
    });

    test('строка, добавленная на клиенте, помечает таблицу загруженной', () {
      final owner = TableOwner()..id = 'O2';
      final row = TableRow_()
        ..id = 'R1'
        ..setFieldValue(TableRow_.nameText, 'первая');
      owner.rows.addRow(row);

      expect(owner.isTableLoaded(TableOwner.nameRows), isTrue,
          reason: 'иначе контроллер спрятал бы только что добавленную строку');
      expect(owner.rows.rows.length, 1);
    });

    test('пришедшая с сервера пустая таблица считается загруженной', () {
      final owner = TableOwner()..id = 'O3';
      owner.setFieldValue(TableOwner.nameRows, <TableRow_>[]);

      expect(owner.isTableLoaded(TableOwner.nameRows), isTrue,
          reason: '«загружена и пуста» надо отличать от «не читали»');
      expect(owner.rows.rows, isEmpty);
    });
  });
}
