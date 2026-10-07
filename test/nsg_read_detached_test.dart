// Отвязанное повторное чтение (readDetached) — NSG-SOFT/futbolista-tasks#2253.
//
// По умолчанию повторное чтение того же id ВЛИВАЕТ свежие значения в уже
// кэшированный экземпляр (намеренное слияние #1394: экземпляр держится прежний,
// сужение запроса не делает его беднее). Побочный эффект: несохранённые правки
// на открытом экране молча затираются серверной версией.
//
// NsgDataRequestParams.readDetached = true — opt-in для экрана, который правит
// объект «на месте»: чтение возвращает новые инстансы и не трогает кэш вовсе.
// Поведение по умолчанию этим не меняется.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class DetRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameText = 'text';

  @override
  String get typeName => 'DetRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId), primaryKey: false);
    addField(NsgDataStringField(nameText), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => DetRow();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);
}

class DetItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameCity = 'city';
  static const nameRows = 'rows';

  @override
  String get typeName => 'DetItem';

  @override
  String get apiRequestItems => '/Api/DetItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
    addField(NsgDataStringField(nameCity), primaryKey: false);
    addField(NsgDataReferenceListField<DetRow>(nameRows), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => DetItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<DetRow> get rows => NsgDataTable<DetRow>(owner: this, fieldName: nameRows);
}

void main() {
  late HttpServer server;
  late NsgDataProvider provider;

  /// Ответ «сервера»: одна и та же версия объекта на каждый запрос.
  List<Map<String, dynamic>> serverPayload() => [
        {
          'id': 'T1',
          'name': 'Спартак-сервер',
          'city': 'Москва-сервер',
          'rows': [
            {'id': 'R1', 'ownerId': 'T1', 'text': 'строка-сервер'},
          ],
        },
      ];

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(serverPayload()));
      await request.response.close();
    });
    final baseUrl = 'http://${InternetAddress.loopbackIPv4.address}:${server.port}';
    provider = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '1.0',
      availableServers: NsgServerParams(<String, String>{}, ''),
    )..serverUri = baseUrl;
    if (!NsgDataClient.client.isRegistered(DetItem)) {
      NsgDataClient.client.registerDataItem(DetItem(), remoteProvider: provider);
    }
    if (!NsgDataClient.client.isRegistered(DetRow)) {
      NsgDataClient.client.registerDataItem(DetRow(), remoteProvider: provider);
    }
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  Future<DetItem> readById({bool readDetached = false}) async {
    final cmp = NsgCompare();
    cmp.add(name: DetItem.nameId, value: 'T1', comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<DetItem>(dataItemType: DetItem);
    final items = await request.requestItems(
      filter: NsgDataRequestParams(compare: cmp, readDetached: readDetached),
      loadReference: [],
      autoRepeate: false,
    );
    expect(items, hasLength(1));
    return items.first;
  }

  test('readDetached: несохранённые правки скаляра и строки таблицы переживают перечитывание', () async {
    // Первое чтение — обычное: объект кладётся в кэш, экран держит его же.
    final first = await readById();
    final cached = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1');
    expect(identical(cached, first), isTrue);

    // Пользователь правит объект «на месте»: скаляр и строку табличной части.
    first.setFieldValue(DetItem.nameName, 'ЧЕРНОВИК');
    first.rows.rows.first.setFieldValue(DetRow.nameText, 'ЧЕРНОВИК-СТРОКА');

    // Фоновое перечитывание того же id — отвязанное.
    final detached = await readById(readDetached: true);

    expect(identical(detached, first), isFalse, reason: 'отвязанное чтение возвращает новый инстанс');
    expect(detached.getFieldValue(DetItem.nameName), 'Спартак-сервер');
    expect(detached.rows.rows.first.getFieldValue(DetRow.nameText), 'строка-сервер');

    final cachedAfter = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1')!;
    expect(identical(cachedAfter, first), isTrue, reason: 'экземпляр в кэше не подменён');
    expect(cachedAfter.getFieldValue(DetItem.nameName), 'ЧЕРНОВИК', reason: 'правка скаляра не затёрта');
    expect(cachedAfter.rows.rows.first.getFieldValue(DetRow.nameText), 'ЧЕРНОВИК-СТРОКА',
        reason: 'правка строки табличной части не затёрта');
    expect(cachedAfter.getFieldValue(DetItem.nameCity), 'Москва-сервер',
        reason: 'поле без правок тоже осталось прежним — слияния не было вовсе');
  });

  test('по умолчанию повторное чтение мержит в тот же экземпляр (#1394 не сломан)', () async {
    // requestItems всегда возвращает свежие инстансы; слияние — побочный эффект
    // на кэш. Поэтому держателем «объекта экрана» считаем запись кэша.
    final before = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1')!;
    before.setFieldValue(DetItem.nameName, 'ЧЕРНОВИК-2');

    await readById();

    final cached = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1');
    expect(identical(cached, before), isTrue, reason: 'identity кэшированного объекта сохраняется');
    expect(cached!.getFieldValue(DetItem.nameName), 'Спартак-сервер',
        reason: 'default: свежие значения вливаются в прежний экземпляр, как и было');
  });

  test('readDetached не уходит в JSON фильтра на сервер', () {
    final json = NsgDataRequestParams(readDetached: true).toJson();
    expect(json.values.any((v) => v.toString().toLowerCase().contains('detached')), isFalse);
  });
}
