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

class DetCoach extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'DetCoach';

  @override
  String get apiRequestItems => '/Api/DetCoach';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => DetCoach();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class DetItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameCity = 'city';
  static const nameRows = 'rows';
  static const nameCoachId = 'coachId';

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
    addField(NsgDataReferenceField<DetCoach>(nameCoachId), primaryKey: false);
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
  /// Переопределяется в тестах, где нужен другой состав ответа.
  var payload = <Map<String, dynamic>>[];
  var coachPayload = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> defaultPayload() => [
        {
          'id': 'T1',
          'name': 'Спартак-сервер',
          'city': 'Москва-сервер',
          'coachId': 'C1',
          'rows': [
            {'id': 'R1', 'ownerId': 'T1', 'text': 'строка-сервер'},
          ],
        },
      ];

  List<Map<String, dynamic>> defaultCoachPayload() => [
        {'id': 'C1', 'name': 'Тренер-сервер'},
      ];

  setUp(() {
    payload = defaultPayload();
    coachPayload = defaultCoachPayload();
  });

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      final body = request.uri.path.endsWith('DetCoach') ? coachPayload : payload;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
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
    if (!NsgDataClient.client.isRegistered(DetCoach)) {
      NsgDataClient.client.registerDataItem(DetCoach(), remoteProvider: provider);
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

  test('getById(readDetached: true) обновляет свой объект и не трогает кэш', () async {
    final cached = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1')!;
    cached.setFieldValue(DetItem.nameName, 'КЭШ-МАРКЕР');

    final own = DetItem()..id = 'T1';
    final result = await own.getById(readDetached: true);

    expect(identical(result, own), isTrue);
    expect(own.getFieldValue(DetItem.nameName), 'Спартак-сервер', reason: 'свой объект получил свежие значения');
    final cachedAfter = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1');
    expect(identical(cachedAfter, cached), isTrue);
    expect(cachedAfter!.getFieldValue(DetItem.nameName), 'КЭШ-МАРКЕР', reason: 'кэшированный экземпляр не затёрт');
  });

  test('requestItem(addCount: false) уважает readDetached', () async {
    final cached = NsgDataClient.client.getItemsFromCacheTyped<DetItem>('T1')!;
    cached.setFieldValue(DetItem.nameName, 'МАРКЕР-ADDCOUNT');

    final cmp = NsgCompare();
    cmp.add(name: DetItem.nameId, value: 'T1', comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<DetItem>(dataItemType: DetItem);
    final item = await request.requestItem(
      filter: NsgDataRequestParams(compare: cmp, readDetached: true),
      addCount: false,
      loadReference: [],
    );

    expect(item.getFieldValue(DetItem.nameName), 'Спартак-сервер');
    expect(cached.getFieldValue(DetItem.nameName), 'МАРКЕР-ADDCOUNT',
        reason: 'addCount:false не должен молча терять readDetached');
  });

  test('requestItem(addCount: true) клонирует фильтр целиком', () {
    final filter = NsgDataRequestParams(readDetached: true)
      ..neededFields = ['name']
      ..transactionId = 'tr-1'
      ..requestId = 'rq-1';
    final clone = filter.clone()..count = 1;
    expect(clone.readDetached, isTrue);
    expect(clone.neededFields, ['name']);
    expect(clone.transactionId, 'tr-1');
    expect(clone.requestId, 'rq-1');
  });

  test('readDetached с тёплым референтом: кэш референта не мутирует, ссылка — общий экземпляр (root-only)', () async {
    final coach = DetCoach()
      ..id = 'C1'
      ..setFieldValue(DetCoach.nameName, 'ЧЕРНОВИК-ТРЕНЕР');
    NsgDataClient.client.addItemsToCache(items: [coach]);

    final cmp = NsgCompare();
    cmp.add(name: DetItem.nameId, value: 'T1', comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<DetItem>(dataItemType: DetItem);
    final items = await request.requestItems(
      filter: NsgDataRequestParams(compare: cmp, readDetached: true),
      loadReference: ['coachId'],
      autoRepeate: false,
    );
    final item = items.first;

    final cachedCoach = NsgDataClient.client.getItemsFromCacheTyped<DetCoach>('C1');
    expect(identical(cachedCoach, coach), isTrue, reason: 'дочитывание в detached-режиме не переписало кэш');
    expect(cachedCoach!.getFieldValue(DetCoach.nameName), 'ЧЕРНОВИК-ТРЕНЕР',
        reason: 'черновик референта не затёрт серверной версией');

    // Документированный root-only режим: поля-ссылки возвращённого объекта
    // резолвятся через общий кэш и НЕ являются независимыми копиями.
    final field = item.fieldList.fields[DetItem.nameCoachId] as NsgDataReferenceField<DetCoach>;
    expect(identical(field.getReferent(item), coach), isTrue);
  });

  test('readDetached с холодным референтом: дочитывание не пишет в кэш', () async {
    payload = defaultPayload()..first['coachId'] = 'COLD9';
    coachPayload = [
      {'id': 'COLD9', 'name': 'Холодный тренер'},
    ];

    final cmp = NsgCompare();
    cmp.add(name: DetItem.nameId, value: 'T1', comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<DetItem>(dataItemType: DetItem);
    await request.requestItems(
      filter: NsgDataRequestParams(compare: cmp, readDetached: true),
      loadReference: ['coachId'],
      autoRepeate: false,
    );

    expect(NsgDataClient.client.getItemsFromCacheTyped<DetCoach>('COLD9', allowNull: true), isNull,
        reason: 'побочных записей в кэш быть не должно — референт читается отдельным detached-запросом');
  });

  test('readDetached не уходит в JSON фильтра на сервер', () {
    final json = NsgDataRequestParams(readDetached: true).toJson();
    expect(json.values.any((v) => v.toString().toLowerCase().contains('detached')), isFalse);
  });
}
