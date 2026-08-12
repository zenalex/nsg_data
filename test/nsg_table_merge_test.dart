// Регрессия на слияние табличных частей при перечитывании объекта.
//
// #1394 переписал ветку табличных частей в copyFieldValues: строки теперь
// переиспользуются по row.id, а не пересоздаются заново. Ошибка в этом месте
// выглядит на экране как «строки пропали» (например, афиши у новости) и при
// этом не бросает исключения — молчаливая потеря данных. Поэтому держим тесты
// на четыре ситуации, в которых слияние легко испортить: источник длиннее
// кэша, совпадающие id, строка добавлена на клиенте и ещё не сохранена,
// повторные перечитывания подряд.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';

class MrgRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'MrgRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId), primaryKey: false);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => MrgRow();

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

class MrgNews extends NsgDataItem {
  static const nameId = 'id';
  static const nameTable = 'bannerPages';

  @override
  String get typeName => 'MrgNews';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceListField<MrgRow>(nameTable), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => MrgNews();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<MrgRow> get pages => NsgDataTable<MrgRow>(owner: this, fieldName: nameTable);
}

void main() {
  late NsgDataProvider provider;

  setUpAll(() {
    provider = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '1.0',
      availableServers: NsgServerParams(<String, String>{}, ''),
      newTableLogic: true,
    );
    if (!NsgDataClient.client.isRegistered(MrgRow)) {
      NsgDataClient.client.registerDataItem(MrgRow(), remoteProvider: provider);
    }
    if (!NsgDataClient.client.isRegistered(MrgNews)) {
      NsgDataClient.client.registerDataItem(MrgNews(), remoteProvider: provider);
    }
  });

  MrgRow savedRow(String id, String name, String ownerId) => MrgRow()
    ..id = id
    ..name = name
    ..ownerId = ownerId
    ..state = NsgDataItemState.fill
    ..docState = NsgDataItemDocState.saved;

  MrgNews newsWith(String id, List<MrgRow> rows) {
    final n = MrgNews()..id = id;
    for (final r in rows) {
      n.pages.addRow(r);
    }
    return n;
  }

  group('слияние табличной части при перечитывании', () {
    test('в источнике на строку больше — обе строки на месте', () {
      final cached = newsWith('n1', [savedRow('r1', 'афиша 1', 'n1')]);
      final fromServer = newsWith('n1', [
        savedRow('r1', 'афиша 1', 'n1'),
        savedRow('r2', 'афиша 2', 'n1'),
      ]);

      cached.copyFieldValues(fromServer);

      expect(cached.pages.rows.map((e) => e.id).toList(), ['r1', 'r2']);
      expect(cached.pages.rows.map((e) => e.name).toList(), ['афиша 1', 'афиша 2']);
    });

    test('те же id — строки не схлопываются, значения обновляются', () {
      final cached = newsWith('n1', [
        savedRow('r1', 'старое 1', 'n1'),
        savedRow('r2', 'старое 2', 'n1'),
      ]);
      final fromServer = newsWith('n1', [
        savedRow('r1', 'новое 1', 'n1'),
        savedRow('r2', 'новое 2', 'n1'),
      ]);

      cached.copyFieldValues(fromServer);

      expect(cached.pages.rows.length, 2);
      expect(cached.pages.rows.map((e) => e.name).toList(), ['новое 1', 'новое 2']);
    });

    test('строка, добавленная на клиенте, доезжает и возвращается с сервера', () {
      final cached = newsWith('n1', [savedRow('r1', 'афиша 1', 'n1')]);
      final added = MrgRow()..name = 'афиша 2';
      cached.pages.addRow(added);
      final assignedId = added.id;

      expect(assignedId.isNotEmpty, isTrue, reason: 'addRow обязан выдать строке id');
      expect(cached.pages.rows.length, 2, reason: 'до сохранения на экране должны быть обе');

      final fromServer = newsWith('n1', [
        savedRow('r1', 'афиша 1', 'n1'),
        savedRow(assignedId, 'афиша 2', 'n1'),
      ]);

      cached.copyFieldValues(fromServer);

      expect(cached.pages.rows.length, 2, reason: 'после перечитывания обе афиши должны остаться');
      expect(cached.pages.rows.map((e) => e.id).toList(), ['r1', assignedId]);
    });

    test('перечитывание подряд не накапливает и не теряет строки', () {
      final cached = newsWith('n1', [savedRow('r1', 'а', 'n1')]);
      final fromServer = newsWith('n1', [savedRow('r1', 'а', 'n1'), savedRow('r2', 'б', 'n1')]);

      cached.copyFieldValues(fromServer);
      cached.copyFieldValues(fromServer);
      cached.copyFieldValues(fromServer);

      expect(cached.pages.rows.map((e) => e.id).toList(), ['r1', 'r2']);
    });

    test('клон объекта с таблицей сохраняет все строки', () {
      final cached = newsWith('n1', [savedRow('r1', 'а', 'n1'), savedRow('r2', 'б', 'n1')]);

      final clone = cached.clone() as MrgNews;

      expect(clone.pages.rows.map((e) => e.id).toList(), ['r1', 'r2']);
    });
  });
}
