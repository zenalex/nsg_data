// Тесты табличной части (NsgDataTable):
//  - добавление строк
//  - удаление строк (newTableLogic true/false, новые/сохранённые)
//  - сериализация для POST: удалённые строки уходят с docState=deleted и флагом
//  - имитация чтения объекта с таб. частью с сервера (ссылочный список)
//  - регресс-гард: обновление объекта из БД не оставляет «мёртвых» (deleted) строк
//
// Регресс, который ловят последние два теста: если clear() помечает сохранённые
// строки deleted и оставляет их в списке (а не удаляет физически), то при
// перечитывании/обновлении объекта через copyFieldValues в нём копятся
// строки-надгробия и «подтягиваются удалённые строки».

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';

class TestRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'TestRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId), primaryKey: false);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TestRow();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);

  String get name => getFieldValue(nameName).toString();
  set name(String value) => setFieldValue(nameName, value);
}

///Строка без поля ownerId — addRow/insertRow не должны пытаться его проставить
class TestRowNoOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'TestRowNoOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TestRowNoOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class TestOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameTable = 'table';
  static const nameTableNoOwner = 'tableNoOwner';

  @override
  String get typeName => 'TestOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceListField<TestRow>(nameTable), primaryKey: false);
    addField(NsgDataReferenceListField<TestRowNoOwner>(nameTableNoOwner), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TestOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<TestRow> get table => NsgDataTable<TestRow>(owner: this, fieldName: nameTable);
  NsgDataTable<TestRowNoOwner> get tableNoOwner => NsgDataTable<TestRowNoOwner>(owner: this, fieldName: nameTableNoOwner);
}

void main() {
  // Один общий провайдер: newTableLogic — мутабельный флаг, переключаем по тестам.
  late NsgDataProvider provider;

  setUpAll(() {
    provider = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '1.0',
      availableServers: NsgServerParams(<String, String>{}, ''),
      newTableLogic: true,
    );
    if (!NsgDataClient.client.isRegistered(TestRow)) {
      NsgDataClient.client.registerDataItem(TestRow(), remoteProvider: provider);
    }
    if (!NsgDataClient.client.isRegistered(TestRowNoOwner)) {
      NsgDataClient.client.registerDataItem(TestRowNoOwner(), remoteProvider: provider);
    }
    if (!NsgDataClient.client.isRegistered(TestOwner)) {
      NsgDataClient.client.registerDataItem(TestOwner(), remoteProvider: provider);
    }
  });

  setUp(() => provider.newTableLogic = true);

  // Строка в состоянии «прочитана/сохранена на сервере».
  TestRow savedRow(String id, String name, String ownerId) {
    return TestRow()
      ..id = id
      ..name = name
      ..ownerId = ownerId
      ..state = NsgDataItemState.fill
      ..docState = NsgDataItemDocState.saved;
  }

  TestOwner ownerWith(String id, List<TestRow> rows) {
    final o = TestOwner()..id = id;
    for (final r in rows) {
      o.table.addRow(r);
    }
    return o;
  }

  group('addRow', () {
    test('добавляет строку, новой строке выдаётся id', () {
      final owner = TestOwner()..id = 'o1';
      expect(owner.table.length, 0);

      final row = TestRow()..name = 'A';
      owner.table.addRow(row);

      expect(owner.table.length, 1);
      expect(owner.table.rows.single.name, 'A');
      expect(owner.table.rows.single.isNotEmpty, true, reason: 'новой строке должен присвоиться id');
    });

    test('строка попадает и в rows, и в allRows', () {
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1')]);
      expect(owner.table.rows.length, 1);
      expect(owner.table.allRows.length, 1);
    });

    test('новой строке проставляется ownerId владельца', () {
      final owner = TestOwner()..id = 'o1';
      final row = TestRow()..name = 'A';
      expect(row.ownerId, isEmpty);

      owner.table.addRow(row);

      expect(row.ownerId, 'o1');
    });

    test('строка с чужим ownerId перепривязывается к новому владельцу', () {
      // на это поведение полагается прикладной код (копирование строк между объектами)
      final owner = TestOwner()..id = 'o2';
      final row = savedRow('r1', 'A', 'o1');

      owner.table.addRow(row);

      expect(row.ownerId, 'o2');
    });

    test('строка без поля ownerId добавляется без ошибок', () {
      final owner = TestOwner()..id = 'o1';
      final row = TestRowNoOwner();
      row.setFieldValue(TestRowNoOwner.nameName, 'A');

      owner.tableNoOwner.addRow(row);

      expect(owner.tableNoOwner.length, 1);
      expect(row.fieldValues.fields.containsKey(NsgDataItem.nameOwnerId), false, reason: 'несуществующее поле не должно появиться');
    });
  });

  group('insertRow', () {
    test('вставляет по индексу и проставляет ownerId', () {
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1'), savedRow('r2', 'B', 'o1')]);
      final row = TestRow()..name = 'C';

      owner.table.insertRow(1, row);

      expect(owner.table.rows.map((e) => e.name), ['A', 'C', 'B']);
      expect(row.ownerId, 'o1');
      expect(row.isNotEmpty, true, reason: 'новой строке должен присвоиться id');
    });

    test('строка без поля ownerId вставляется без ошибок', () {
      final owner = TestOwner()..id = 'o1';
      final row = TestRowNoOwner();

      owner.tableNoOwner.insertRow(0, row);

      expect(owner.tableNoOwner.length, 1);
    });
  });

  group('removeRow', () {
    test('newTableLogic=true: сохранённая строка помечается deleted и остаётся в allRows', () {
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1'), savedRow('r2', 'B', 'o1')]);
      final r1 = owner.table.allRows.firstWhere((e) => e.id == 'r1');

      owner.table.removeRow(r1);

      expect(r1.docState, NsgDataItemDocState.deleted);
      // rows скрывает удалённые, allRows — нет (нужно для отправки удаления на сервер)
      expect(owner.table.rows.map((e) => e.id), ['r2']);
      expect(owner.table.allRows.length, 2);
      expect(owner.table.allRows.any((e) => e.id == 'r1' && e.docState == NsgDataItemDocState.deleted), true);
    });

    test('newTableLogic=true: новая (несохранённая) строка удаляется физически', () {
      final owner = TestOwner()..id = 'o1';
      final row = TestRow()..name = 'A'; // docState=created по умолчанию
      owner.table.addRow(row);

      owner.table.removeRow(row);

      expect(owner.table.rows, isEmpty);
      expect(owner.table.allRows, isEmpty, reason: 'несохранённую строку не за чем помечать deleted');
    });

    test('newTableLogic=false: сохранённая строка удаляется физически', () {
      provider.newTableLogic = false;
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1')]);
      final r1 = owner.table.allRows.single;

      owner.table.removeRow(r1);

      expect(owner.table.allRows, isEmpty);
    });
  });

  group('POST-сериализация', () {
    test('удалённая строка сериализуется только ключом + docState=deleted + newTableLogic', () {
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1')]);
      final r1 = owner.table.allRows.single;
      owner.table.removeRow(r1);

      final json = r1.toJson();

      expect(json['id'], 'r1');
      expect(json['docState'], NsgDataItemDocState.deleted.index);
      expect(json['newTableLogic'], true);
      // данные удалённой строки на сервер не гоняем
      expect(json.containsKey('name'), false);
    });

    test('обычная строка сериализуется со всеми полями', () {
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1')]);
      final json = owner.table.allRows.single.toJson();

      expect(json['id'], 'r1');
      expect(json['name'], 'A');
      expect(json['docState'], NsgDataItemDocState.saved.index);
    });

    test('удалённая строка остаётся в таб. части владельца для отправки на сервер', () {
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1'), savedRow('r2', 'B', 'o1')]);
      owner.table.removeRow(owner.table.allRows.firstWhere((e) => e.id == 'r1'));

      final tableJson = owner.toJson()[TestOwner.nameTable] as List;
      expect(tableJson.length, 2, reason: 'и удалённая, и оставшаяся строка уходят в POST');
    });
  });

  group('чтение с сервера', () {
    Map<String, dynamic> serverResponse(List<Map<String, dynamic>> rows) => {
          'results': [
            {
              'id': 'o1',
              'state': NsgDataItemState.fill.index,
              'docState': NsgDataItemDocState.saved.index,
              'table': rows,
            },
          ],
        };

    Map<String, dynamic> rowMap(String id, String name) => {
          'id': id,
          'name': name,
          'ownerId': 'o1',
          'state': NsgDataItemState.fill.index,
          'docState': NsgDataItemDocState.saved.index,
        };

    test('таб. часть подтягивается как ссылочный список', () async {
      final req = NsgDataRequest<TestOwner>(dataItemType: TestOwner);
      final items = await req.loadDataAndReferences(
        serverResponse([rowMap('r1', 'A'), rowMap('r2', 'B')]),
        [TestOwner.nameTable],
        '',
      );

      expect(items.length, 1);
      final owner = items.single as TestOwner;
      expect(owner.table.rows.map((e) => e.id), ['r1', 'r2']);
      expect(owner.table.allRows.any((e) => e.docState == NsgDataItemDocState.deleted), false);
    });

    test('повторное чтение не подтягивает лишних строк из кэша', () async {
      final req = NsgDataRequest<TestOwner>(dataItemType: TestOwner);
      // первое чтение — 2 строки
      await req.loadDataAndReferences(serverResponse([rowMap('r1', 'A'), rowMap('r2', 'B')]), [TestOwner.nameTable], '');
      // на сервере строку удалили — теперь приходит 1 строка
      final items = await req.loadDataAndReferences(serverResponse([rowMap('r1', 'A')]), [TestOwner.nameTable], '');

      final owner = items.single as TestOwner;
      expect(owner.table.rows.map((e) => e.id), ['r1']);
      expect(owner.table.allRows.length, 1, reason: 'строка r2 из прошлого чтения не должна остаться');

      // и из кэша достаётся ровно текущее состояние
      final cached = NsgDataClient.client.getItemsFromCache(TestOwner, 'o1') as TestOwner;
      expect(cached.table.rows.map((e) => e.id), ['r1']);
    });
  });

  group('обновление объекта из БД (регресс-гард)', () {
    test('copyFieldValues не оставляет deleted-надгробий в таб. части', () {
      // объект уже в памяти с двумя сохранёнными строками (как после прошлого чтения)
      final owner = ownerWith('o1', [savedRow('r1', 'A', 'o1'), savedRow('r2', 'B', 'o1')]);
      // свежий снимок с сервера: строки r2 больше нет
      final fresh = ownerWith('o1', [savedRow('r1', 'A', 'o1')]);

      // именно так обновляется существующий объект при getById/обновлении кэша
      owner.copyFieldValues(fresh);

      expect(owner.table.rows.map((e) => e.id), ['r1']);
      expect(owner.table.allRows.length, 1, reason: 'r2 не должна остаться как deleted-надгробие');
      expect(owner.table.allRows.any((e) => e.docState == NsgDataItemDocState.deleted), false);
    });
  });
}
