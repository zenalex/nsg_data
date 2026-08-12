// Слияние объектов в кэше вместо замены + признак загруженности табличной части (#1394).
//
// Зачем: при сужении запросов экран, прочитавший объект узко, вытеснял из кэша полную
// версию. Ломался при этом не он, а соседний экран — тот резолвил через кэш ссылку и
// не находил поля. Слияние даёт свойство «сужение не может сделать кэшированный объект
// беднее, чем он был», и только после этого сужение вообще безопасно раскатывать.
//
// Признак загруженности нужен здесь же: чтение незагруженной таблицы материализует в
// объект пустой список (убрать нельзя — на него опирается прямое добавление строк через
// allRows), поэтому «не загружена» иначе неотличима от «загружена и пуста», и слияние
// обнуляло бы таблицу, которую просто ни разу не читали.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';
// NsgItemList не в бочке экспортов - это внутренний кэш, импортируем напрямую.
import 'package:nsg_data/nsg_data_itemList.dart';

class CacheRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameText = 'text';

  @override
  String get typeName => 'CacheRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId), primaryKey: false);
    addField(NsgDataStringField(nameText), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => CacheRow();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);
}

class CacheItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameCity = 'city';
  static const nameRows = 'rows';

  @override
  String get typeName => 'CacheItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
    addField(NsgDataStringField(nameCity), primaryKey: false);
    addField(NsgDataReferenceListField<CacheRow>(nameRows), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => CacheItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<CacheRow> get rows => NsgDataTable<CacheRow>(owner: this, fieldName: nameRows);
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
    if (!NsgDataClient.client.isRegistered(CacheItem)) {
      NsgDataClient.client.registerDataItem(CacheItem(), remoteProvider: provider);
    }
    if (!NsgDataClient.client.isRegistered(CacheRow)) {
      NsgDataClient.client.registerDataItem(CacheRow(), remoteProvider: provider);
    }
  });

  group('слияние в кэше', () {
    test('узкая версия не вытесняет уже известные поля', () {
      final list = NsgItemList();

      final wide = CacheItem()
        ..id = 'T1'
        ..setFieldValue(CacheItem.nameName, 'Спартак')
        ..setFieldValue(CacheItem.nameCity, 'Москва');
      list.add(item: wide);

      // Второй экран прочитал тот же объект узко: city он не запрашивал.
      final narrow = CacheItem()
        ..id = 'T1'
        ..setFieldValue(CacheItem.nameName, 'Спартак-2');
      narrow.setFieldEmpty(CacheItem.nameCity);
      list.add(item: narrow);

      final cached = list.getItem('T1')!.dataItem as CacheItem;
      expect(cached.getFieldValue(CacheItem.nameName), 'Спартак-2', reason: 'свежее значение выигрывает');
      expect(cached.getFieldValue(CacheItem.nameCity), 'Москва', reason: 'то, что уже знали, теряться не должно');
    });

    test('экземпляр в кэше сохраняется — открытые экраны держат на него ссылку', () {
      final list = NsgItemList();
      final first = CacheItem()
        ..id = 'T2'
        ..setFieldValue(CacheItem.nameName, 'ЦСКА');
      list.add(item: first);

      list.add(item: CacheItem()
        ..id = 'T2'
        ..setFieldValue(CacheItem.nameName, 'ЦСКА-2'));

      expect(identical(list.getItem('T2')!.dataItem, first), isTrue);
      expect(first.getFieldValue(CacheItem.nameName), 'ЦСКА-2', reason: 'обновление видно всем держателям объекта');
    });

    test('новый объект кладётся как есть', () {
      final list = NsgItemList();
      final item = CacheItem()..id = 'T3';
      list.add(item: item);
      expect(identical(list.getItem('T3')!.dataItem, item), isTrue);
    });
  });

  group('признак загруженности табличной части', () {
    test('чтение незагруженной таблицы не делает её загруженной', () {
      final item = CacheItem()..id = 'A';
      expect(item.isTableLoaded(CacheItem.nameRows), isFalse);

      // Материализует пустой список в fields — но это не загрузка.
      expect(item.rows.allRows, isEmpty);
      expect(item.isTableLoaded(CacheItem.nameRows), isFalse);
    });

    test('добавление строки помечает таблицу загруженной', () {
      final item = CacheItem()..id = 'B';
      item.rows.addRow(CacheRow()
        ..id = 'R1'
        ..setFieldValue(CacheRow.nameText, 'строка'));
      expect(item.isTableLoaded(CacheItem.nameRows), isTrue);
    });

    test('слияние с незагруженной таблицей источника не обнуляет приёмник', () {
      final target = CacheItem()..id = 'C';
      target.rows.addRow(CacheRow()
        ..id = 'R1'
        ..setFieldValue(CacheRow.nameText, 'важная строка'));

      // Источник ту же таблицу не читал вовсе.
      final source = CacheItem()
        ..id = 'C'
        ..setFieldValue(CacheItem.nameName, 'обновлено');
      target.copyFieldValues(source);

      expect(target.rows.rows.length, 1, reason: 'таблицу, которую источник не читал, трогать нельзя');
      expect(target.getFieldValue(CacheItem.nameName), 'обновлено');
    });

    test('слияние с загруженной пустой таблицей источника приёмник очищает', () {
      final target = CacheItem()..id = 'D';
      target.rows.addRow(CacheRow()..id = 'R1');

      final source = CacheItem()..id = 'D';
      source.setFieldValue(CacheItem.nameRows, <NsgDataItem>[]);
      expect(source.isTableLoaded(CacheItem.nameRows), isTrue);

      target.copyFieldValues(source);

      expect(target.rows.rows, isEmpty, reason: 'источник таблицу читал и она пуста — это законное состояние');
      expect(target.isTableLoaded(CacheItem.nameRows), isTrue);
    });
  });

  group('слияние строк табличной части', () {
    test('строка с тем же id сохраняет поля, которых нет в источнике', () {
      final target = CacheItem()..id = 'E';
      target.rows.addRow(CacheRow()
        ..id = 'R1'
        ..setFieldValue(CacheRow.nameText, 'дочитано раньше'));
      final keptRow = target.rows.rows.first;

      // Источник ту же строку прочитал узко: text не запрашивал.
      final freshRow = CacheRow()..id = 'R1';
      freshRow.setFieldEmpty(CacheRow.nameText);
      final source = CacheItem()..id = 'E';
      source.rows.addRow(freshRow);

      target.copyFieldValues(source);

      expect(target.rows.rows.length, 1);
      expect(target.rows.rows.first.getFieldValue(CacheRow.nameText), 'дочитано раньше',
          reason: 'та же строка: поле, которого нет в свежей версии, теряться не должно');
      expect(identical(target.rows.rows.first, keptRow), isTrue,
          reason: 'экземпляр строки сохраняется — на него могут ссылаться виджеты');
    });

    test('состав строк задаёт источник: лишние не остаются, новые приходят', () {
      final target = CacheItem()..id = 'F';
      target.rows.addRow(CacheRow()..id = 'R1');
      target.rows.addRow(CacheRow()..id = 'R2');

      final source = CacheItem()..id = 'F';
      source.rows.addRow(CacheRow()
        ..id = 'R2'
        ..setFieldValue(CacheRow.nameText, 'осталась'));
      source.rows.addRow(CacheRow()..id = 'R3');

      target.copyFieldValues(source);

      expect(target.rows.rows.map((e) => e.id).toList(), ['R2', 'R3']);
      expect(target.rows.rows.first.getFieldValue(CacheRow.nameText), 'осталась');
    });

    test('свежее значение строки выигрывает у прежнего', () {
      final target = CacheItem()..id = 'G';
      target.rows.addRow(CacheRow()
        ..id = 'R1'
        ..setFieldValue(CacheRow.nameText, 'старое'));

      final source = CacheItem()..id = 'G';
      source.rows.addRow(CacheRow()
        ..id = 'R1'
        ..setFieldValue(CacheRow.nameText, 'новое'));

      target.copyFieldValues(source);

      expect(target.rows.rows.first.getFieldValue(CacheRow.nameText), 'новое');
    });
  });
}
