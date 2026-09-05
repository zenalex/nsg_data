// `getReferentAsync` действительно дочитывает референт (NSG-SOFT/futbolista-tasks#1921).
//
// Метод обещает «нет объекта — сходи за ним», и не делал этого никогда. Ветка
// загрузки стояла под `if (item == null)`, а `getReferent` звался без
// `allowNull` — то есть с `allowNull: false`, при котором промах кэша возвращает
// не null, а пустышку. Условие не выполнялось ни разу: запрос не уходил,
// вызывающий получал пустой объект и событие промаха в диагностике, а метод был
// синхронным геттером в обёртке `Future`.
//
// Мёртвый код прятал ещё два дефекта, и оживление одной только ветки сделало бы
// хуже, чем было. Поэтому здесь закреплены все три свойства сразу:
//
//  1. запрос уходит;
//  2. фильтр — по первичному ключу РЕФЕРЕНТА, а не по имени поля ВЛАДЕЛЬЦА;
//  3. пустой ответ отдаёт пустышку, а не роняет `Null check operator`.
//
// Плюс два свойства, которые ломать нельзя: по кэшу не ходим на сервер, и проба
// кэша не шумит в диагностику промахов (#1547).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class AsyncRefType extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'AsyncRefType';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  String get apiRequestItems => '/Api/AsyncRefType';

  @override
  NsgDataItem getNewObject() => AsyncRefType();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class AsyncRefOwner extends NsgDataItem {
  static const nameId = 'id';

  /// Имя СОЗНАТЕЛЬНО не совпадает с первичным ключом референта (`id`): именно на
  /// этом различии и видно, по какому полю собирается фильтр дочитывания.
  static const nameTypeId = 'typeId';

  @override
  String get typeName => 'AsyncRefOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceField<AsyncRefType>(nameTypeId), primaryKey: false);
  }

  @override
  String get apiRequestItems => '/Api/AsyncRefOwner';

  @override
  NsgDataItem getNewObject() => AsyncRefOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  Future<AsyncRefType> typeAsync() => getReferentAsync<AsyncRefType>(nameTypeId);
}

/// Владелец с НЕТИПИЗИРОВАННОЙ ссылкой. У неё свой override `getReferentAsync`
/// с ровно теми же тремя дефектами — а `notificationObjId` из #1921, с которого
/// всё началось, как раз такой.
class AsyncRefUntypedOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameObjId = 'objId';

  @override
  String get typeName => 'AsyncRefUntypedOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataUntypedReferenceField(nameObjId, defaultReferentType: AsyncRefType), primaryKey: false);
  }

  @override
  String get apiRequestItems => '/Api/AsyncRefUntypedOwner';

  @override
  NsgDataItem getNewObject() => AsyncRefUntypedOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  Future<NsgDataItem> objAsync() => getReferentAsync<NsgDataItem>(nameObjId);
}

/// Провайдер, который никуда не ходит: запоминает запросы и отдаёт заготовку.
class _RecordingProvider extends NsgDataProvider {
  _RecordingProvider()
      : super(
          applicationName: 'test',
          firebaseToken: '',
          applicationVersion: '1.0',
          availableServers: NsgServerParams(<String, String>{}, ''),
          newTableLogic: true,
        );

  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  /// Строки, которые «сервер» вернёт на следующий запрос.
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  @override
  Future<dynamic> baseRequestList({
    final String? function,
    final Map<String, dynamic>? params,
    final dynamic postData,
    final Map<String, String?>? headers,
    final String? url,
    final String method = 'GET',
    final NsgCancelToken? cancelToken,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    calls.add(<String, dynamic>{
      'url': url ?? '',
      'method': method,
      'postData': postData,
      'params': params,
    });
    return rows;
  }
}

void main() {
  late _RecordingProvider provider;
  final reportedMisses = <String>[];

  setUpAll(() {
    provider = _RecordingProvider();
    for (final item in <NsgDataItem>[AsyncRefType(), AsyncRefOwner(), AsyncRefUntypedOwner()]) {
      if (!NsgDataClient.client.isRegistered(item.runtimeType)) {
        NsgDataClient.client.registerDataItem(item, remoteProvider: provider);
      }
    }
  });

  setUp(() {
    provider.calls.clear();
    provider.rows = <Map<String, dynamic>>[];
    reportedMisses.clear();
    NsgFieldUsage.reset();
    NsgFieldUsage.onEmptyFieldAccess = (typeName, fieldName) => reportedMisses.add('$typeName.$fieldName');
  });

  tearDownAll(() {
    NsgFieldUsage.onEmptyFieldAccess = null;
  });

  /// Кэш общий на весь прогон и очистить его нечем — поэтому у каждого теста
  /// свои id, как и в `nsg_missing_referent_test.dart`.
  AsyncRefOwner owner(String ownerId, String typeId) {
    final o = AsyncRefOwner();
    o.id = ownerId;
    o.setFieldValue(AsyncRefOwner.nameTypeId, typeId);
    return o;
  }

  group('getReferentAsync дочитывает референт', () {
    test('объекта нет в кэше — запрос уходит и объект возвращается', () async {
      // До #1921 запросов было 0, а возвращалась пустышка.
      provider.rows = [
        {'id': 't-1', 'name': 'Голы'},
      ];

      final type = await owner('o-1', 't-1').typeAsync();

      expect(provider.calls, hasLength(1), reason: 'ветка загрузки была мертва — запрос обязан уйти');
      expect(type.isEmpty, isFalse);
      expect(type.getFieldValue(AsyncRefType.nameName), 'Голы');
    });

    test('фильтр — по первичному ключу референта, а не по имени поля владельца', () async {
      // Здесь стояло `cmp.add(name: name, ...)`, где `name` — поле ВЛАДЕЛЬЦА.
      // Для этой пары типов это дало бы условие по `AsyncRefType.typeId`, поля с
      // таким именем у референта нет вовсе; у самоссылки же (когда владелец и
      // референт одного типа) такое условие отбирает ДЕТЕЙ вместо объекта.
      provider.rows = [
        {'id': 't-2', 'name': 'Передачи'},
      ];

      await owner('o-2', 't-2').typeAsync();

      final sent = jsonEncode(provider.calls.single['postData']);
      expect(sent, contains(AsyncRefType.nameId), reason: 'фильтровать надо по первичному ключу референта');
      expect(sent, isNot(contains(AsyncRefOwner.nameTypeId)), reason: 'имя поля владельца у референта не существует');
      expect(sent, contains('t-2'), reason: 'значением фильтра остаётся id референта');
    });

    test('пустой ответ сервера — пустышка, а не падение', () async {
      // Объект мог быть удалён или скрыт правами. Здесь стоял `item!`, и такой
      // случай падал `Null check operator used on a null value`, не называя ни
      // типа, ни поля.
      provider.rows = <Map<String, dynamic>>[];

      final type = await owner('o-3', 't-нет-такого').typeAsync();

      expect(provider.calls, hasLength(1));
      expect(type.isEmpty, isTrue, reason: 'контракт тот же, что у синхронного getReferent — пустышка, не исключение');
    });

    test('объект уже в кэше — на сервер не ходим и отдаём тот же экземпляр', () async {
      final cached = AsyncRefType();
      cached.id = 't-4';
      cached.setFieldValue(AsyncRefType.nameName, 'Отборы');
      NsgDataClient.client.addItemsToCache(items: [cached]);

      final type = await owner('o-4', 't-4').typeAsync();

      expect(provider.calls, isEmpty, reason: 'кэш есть — запрос лишний');
      expect(identical(type, cached), isTrue, reason: 'должен вернуться экземпляр из кэша');
    });

    test('пустая ссылка — не промах и не запрос', () async {
      final type = await owner('o-5', '').typeAsync();

      expect(provider.calls, isEmpty);
      expect(type.isEmpty, isTrue);
      expect(reportedMisses, isEmpty, reason: 'пустая ссылка — законное состояние');
    });

    test('проба кэша перед дочитыванием не шумит в диагностику промахов', () async {
      // #1547: дедуп в NsgFieldUsage пропускает только ПЕРВОЕ событие пары
      // «тип.поле» за сессию. Пока getReferentAsync щупал кэш с allowNull:false,
      // он съедал это единственное событие — и в отчёт уезжало поле, которое на
      // самом деле дочитывается, а настоящий промах экрана глотался как дубль.
      provider.rows = [
        {'id': 't-6', 'name': 'Сейвы'},
      ];

      await owner('o-6', 't-6').typeAsync();

      expect(reportedMisses, isEmpty, reason: 'загрузчик щупает кэш с allowNull — это не промах экрана');
    });
  });

  // У NsgDataUntypedReferenceField свой override getReferentAsync, и он нёс те
  // же три дефекта. Мимо этого легко пройти: типизированную версию починил, а
  // untyped осталась — при том что поле из #1921 (`notificationObjId`) именно
  // такое, и тип референта у него живёт в самом значении («<guid>.<Тип>»).
  group('getReferentAsync у нетипизированной ссылки', () {
    AsyncRefUntypedOwner untypedOwner(String ownerId, String objId) {
      final o = AsyncRefUntypedOwner();
      o.id = ownerId;
      o.setFieldValue(AsyncRefUntypedOwner.nameObjId, objId);
      return o;
    }

    test('объекта нет в кэше — запрос уходит и объект возвращается', () async {
      provider.rows = [
        {'id': 'u-1', 'name': 'Цель'},
      ];

      final obj = await untypedOwner('uo-1', 'u-1.AsyncRefType').objAsync();

      expect(provider.calls, hasLength(1), reason: 'ветка загрузки была мертва и здесь тоже');
      expect(obj.getFieldValue(AsyncRefType.nameName), 'Цель');
    });

    test('фильтр — по первичному ключу референта, а не по имени поля владельца', () async {
      provider.rows = [
        {'id': 'u-2', 'name': 'Ещё цель'},
      ];

      await untypedOwner('uo-2', 'u-2.AsyncRefType').objAsync();

      final sent = jsonEncode(provider.calls.single['postData']);
      expect(sent, isNot(contains(AsyncRefUntypedOwner.nameObjId)), reason: 'поля владельца у референта нет');
      expect(sent, contains('u-2'), reason: 'фильтруем по guid из untyped-значения');
      expect(sent, isNot(contains('u-2.AsyncRefType')), reason: 'в фильтр идёт guid, а не значение с суффиксом типа');
    });

    test('пустой ответ сервера — пустышка, а не падение', () async {
      provider.rows = <Map<String, dynamic>>[];

      final obj = await untypedOwner('uo-3', 'u-нет.AsyncRefType').objAsync();

      expect(provider.calls, hasLength(1));
      expect(obj.isEmpty, isTrue);
    });

    test('объект в кэше — на сервер не ходим', () async {
      final cached = AsyncRefType();
      cached.id = 'u-4';
      cached.setFieldValue(AsyncRefType.nameName, 'Из кэша');
      NsgDataClient.client.addItemsToCache(items: [cached]);

      final obj = await untypedOwner('uo-4', 'u-4.AsyncRefType').objAsync();

      expect(provider.calls, isEmpty);
      expect(identical(obj, cached), isTrue);
    });
  });
}
