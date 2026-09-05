// Предупреждение о `getReferentAsync` во время сборки кадра
// (NSG-SOFT/futbolista-tasks#1921).
//
// Пока ветка загрузки была мертва, метод в сеть не ходил, и позвать его из
// `build()` было безобидно. Теперь это сетевой запрос, и у такого вызова два
// исхода, оба плохих: результат в сборке всё равно не дождаться, а `Future` без
// `await` при обрыве связи всплывает в `PlatformDispatcher.onError`
// необработанным — ровно тот дефект, что разбирался в соседней задаче #1782.
//
// Защиты от этого нет и быть не может: `xxxAsync()` генерируется у каждой ссылки
// каждой модели и выглядит как безопасная замена синхронному геттеру. Поэтому —
// предупреждение в debug, чтобы место вызова называлось само.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class BuildRefType extends NsgDataItem {
  static const nameId = 'id';

  @override
  String get typeName => 'BuildRefType';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
  }

  @override
  String get apiRequestItems => '/Api/BuildRefType';

  @override
  NsgDataItem getNewObject() => BuildRefType();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class BuildRefOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameTypeId = 'typeId';

  @override
  String get typeName => 'BuildRefOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceField<BuildRefType>(nameTypeId), primaryKey: false);
  }

  @override
  String get apiRequestItems => '/Api/BuildRefOwner';

  @override
  NsgDataItem getNewObject() => BuildRefOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  Future<BuildRefType> typeAsync() => getReferentAsync<BuildRefType>(nameTypeId);
}

void main() {
  final warned = <String>[];

  setUpAll(() {
    for (final item in <NsgDataItem>[BuildRefType(), BuildRefOwner()]) {
      if (!NsgDataClient.client.isRegistered(item.runtimeType)) {
        NsgDataClient.client.registerDataItem(item);
      }
    }
    NsgDataClient.client.addItemsToCache(items: [BuildRefType()..id = 'cached-type']);
  });

  setUp(() {
    warned.clear();
    NsgFieldUsage.reset();
    NsgFieldUsage.onAsyncReferentDuringBuild = (typeName, fieldName, phase) => warned.add('$typeName.$fieldName@$phase');
  });

  tearDown(() {
    NsgFieldUsage.onAsyncReferentDuringBuild = null;
    NsgFieldUsage.strictAsyncReferentDuringBuild = false;
  });

  /// Ссылка СОЗНАТЕЛЬНО разрешается из кэша, провайдер не поднят и запрос не
  /// уходит — иначе `flutter_test` уронит тест на висящем таймере ретраев.
  ///
  /// На проверку это не влияет, а наоборот, показывает главное свойство:
  /// предупреждение стоит НА ВХОДЕ и срабатывает даже когда кэш тёплый и запрос
  /// не понадобился. Место вызова от везения с кэшем верным не становится.
  BuildRefOwner owner(String ownerId) {
    final o = BuildRefOwner();
    o.id = ownerId;
    o.setFieldValue(BuildRefOwner.nameTypeId, 'cached-type');
    return o;
  }

  testWidgets('вызов из build() — предупреждаем и называем фазу', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (_) {
            // Классическая ошибка: результат здесь не дождаться, Future висит
            // без обработчика — `ignore()` только делает это явным.
            owner('b-1').typeAsync().ignore();
            return const SizedBox();
          },
        ),
      ),
    );

    expect(warned, ['BuildRefOwner.typeId@persistentCallbacks'],
        reason: 'сборка виджетов идёт в persistentCallbacks — это и есть нарушение');
  });

  testWidgets('об одном месте предупреждаем один раз, а не на каждый кадр', (tester) async {
    // Перестраивающийся виджет иначе дал бы 60 сообщений в секунду.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (_) {
            owner('b-2').typeAsync().ignore();
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(warned, hasLength(1));
  });

  testWidgets('вне кадра молчим: postFrameCallback — законное место', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      owner('b-3').typeAsync().ignore();
    });
    await tester.pump();

    expect(warned, isEmpty, reason: 'после отрисовки дочитывать — ровно то, что и надо делать');
  });

  test('обычный async-контекст вне кадра не предупреждает', () async {
    // Здесь биндинг вообще не поднят: фазы нет, диагностике сказать нечего.
    await owner('b-4').typeAsync();

    expect(warned, isEmpty);
  });

  testWidgets('хук работает и с выключенным логом — он для release, где лога нет', (tester) async {
    // Лог видит только разработчик у себя, а нарушение живёт в проде. Поэтому
    // хук НЕ привязан к флагу лога (и к режиму сборки — но kReleaseMode это
    // компайл-тайм константа, в тесте её не подменить; здесь закрепляется
    // независимость от флага, форма кода та же).
    NsgFieldUsage.warnAsyncReferentDuringBuild = false;
    addTearDown(() => NsgFieldUsage.warnAsyncReferentDuringBuild = true);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (_) {
            owner('b-6').typeAsync().ignore();
            return const SizedBox();
          },
        ),
      ),
    );

    expect(warned, ['BuildRefOwner.typeId@persistentCallbacks']);
  });

  testWidgets('строгий режим роняет вызов — но ОТКАЗОМ FUTURE, а не throw из build', (tester) async {
    // Важная разница с strictEmptyFields: тот сидит в СИНХРОННОМ геттере и
    // валит сборку на месте. Здесь метод `async`, и синхронный throw из его тела
    // Dart заворачивает в возвращаемый Future. То есть строгий режим ловится
    // обработчиком ошибки, а не `tester.takeException()`, и вызов вида
    // `typeAsync().ignore()` проглотит его молча.
    NsgFieldUsage.strictAsyncReferentDuringBuild = true;
    Object? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (_) {
            owner('b-5').typeAsync().catchError((Object e) {
              captured = e;
              return BuildRefType();
            });
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    expect(captured, isA<AssertionError>(),
        reason: 'строгость — opt-in, но если включена, нарушение обязано быть видно');
    expect(tester.takeException(), isNull, reason: 'из build при этом ничего не вылетает — метод асинхронный');
  });
}
