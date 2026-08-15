// Хранилище состояния v2 (NsgControllerStore) и его снимок.
//
// Зачем: store — единственный источник истины для контроллеров v2, любое
// изменение обязано проходить через update(snapshot.copyWith(...)). Если
// рассылка сломается, экран просто перестанет обновляться — без ошибки, без
// исключения, без следа в логе.
//
// Отдельно фиксируется НЕОЧЕВИДНАЯ асимметрия copyWith: totalCount по
// умолчанию сохраняется (keepCount = true), а error по умолчанию СБРАСЫВАЕТСЯ
// (keepError = false). Это осознанно — каждое новое состояние начинается без
// прошлой ошибки, — но выглядит как опечатка и первым же «наведением порядка»
// чинится в неправильную сторону. Тогда ошибка залипает на экране навсегда.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';
import 'package:nsg_data/v2/controller/nsg_controller_store.dart';

class Row extends NsgDataItem {
  static const nameId = 'id';

  @override
  String get typeName => 'Row';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
  }

  @override
  NsgDataItem getNewObject() => Row();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

Row row(String id) => Row()..id = id;

void main() {
  // Модель обязана быть зарегистрирована в клиенте — иначе setFieldValue падает.
  setUpAll(() {
    if (!NsgDataClient.client.isRegistered(Row)) {
      NsgDataClient.client.registerDataItem(
        Row(),
        remoteProvider: NsgDataProvider(
          applicationName: 'test',
          firebaseToken: '',
          applicationVersion: '1.0',
          availableServers: NsgServerParams(<String, String>{}, ''),
        ),
      );
    }
  });

  group('рассылка', () {
    test('update меняет снимок и доходит до подписчика', () async {
      final store = NsgControllerStore<Row>();
      final seen = <NsgControllerStatus>[];
      store.stream.listen((s) => seen.add(s.status));

      store.update(store.snapshot.copyWith(status: NsgControllerStatus.loading));
      store.update(store.snapshot.copyWith(status: NsgControllerStatus.success, items: [row('1')]));

      await Future<void>.delayed(Duration.zero);

      expect(seen, [NsgControllerStatus.loading, NsgControllerStatus.success]);
      expect(store.snapshot.items.map((e) => e.id), ['1']);
    });

    test('событие получают ВСЕ подписчики, а не первый', () async {
      final store = NsgControllerStore<Row>();
      final first = <int>[];
      final second = <int>[];
      store.stream.listen((s) => first.add(s.items.length));
      store.stream.listen((s) => second.add(s.items.length));

      store.update(store.snapshot.copyWith(items: [row('1'), row('2')]));
      await Future<void>.delayed(Duration.zero);

      expect(first, [2]);
      expect(second, [2], reason: 'broadcast: второй экран обязан увидеть то же самое');
    });

    test('поздний подписчик не получает историю', () async {
      final store = NsgControllerStore<Row>();
      store.update(store.snapshot.copyWith(items: [row('1')]));
      await Future<void>.delayed(Duration.zero);

      final lateSeen = <int>[];
      store.stream.listen((s) => lateSeen.add(s.items.length));
      await Future<void>.delayed(Duration.zero);

      expect(lateSeen, isEmpty, reason: 'состояние берут из snapshot, а из стрима — только изменения');
      expect(store.snapshot.items, hasLength(1), reason: 'зато текущее состояние доступно сразу');
    });
  });

  group('после dispose', () {
    test('update не рассылает и не падает', () async {
      final store = NsgControllerStore<Row>();
      final seen = <int>[];
      store.stream.listen((s) => seen.add(s.items.length));
      await store.dispose();

      store.update(store.snapshot.copyWith(items: [row('1')]));
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty, reason: 'иначе add в закрытый контроллер = исключение на ровном месте');
    });

    test('повторный dispose безопасен', () async {
      final store = NsgControllerStore<Row>();
      await store.dispose();

      await expectLater(store.dispose(), completes);
    });
  });

  group('copyWith', () {
    test('не трогает то, что не передали', () {
      final base = NsgControllerSnapshot<Row>.empty().copyWith(
        items: [row('1')],
        totalCount: 42,
        loadReference: ['tournamentId'],
      );

      final next = base.copyWith(status: NsgControllerStatus.loading);

      expect(next.status, NsgControllerStatus.loading);
      expect(next.items.map((e) => e.id), ['1']);
      expect(next.totalCount, 42);
      expect(next.loadReference, ['tournamentId']);
    });

    test('totalCount по умолчанию СОХРАНЯЕТСЯ', () {
      final base = NsgControllerSnapshot<Row>.empty().copyWith(totalCount: 7);

      expect(base.copyWith(status: NsgControllerStatus.loading).totalCount, 7,
          reason: 'иначе пагинация теряет общее число на каждом чихе');
    });

    test('totalCount сбрасывается только явно, через keepCount: false', () {
      final base = NsgControllerSnapshot<Row>.empty().copyWith(totalCount: 7);

      expect(base.copyWith(keepCount: false).totalCount, isNull);
    });

    test('error по умолчанию СБРАСЫВАЕТСЯ — это не опечатка', () {
      final failed = NsgControllerSnapshot<Row>.empty().copyWith(
        status: NsgControllerStatus.error,
        error: Exception('boom'),
      );

      final retry = failed.copyWith(status: NsgControllerStatus.loading);

      expect(retry.error, isNull,
          reason: 'новая попытка начинается с чистого листа; иначе ошибка залипнет на экране навсегда');
    });

    test('error переживает копию, если попросили явно', () {
      final failed = NsgControllerSnapshot<Row>.empty().copyWith(
        status: NsgControllerStatus.error,
        error: Exception('boom'),
      );

      expect(failed.copyWith(keepError: true).error, isNotNull);
    });
  });
}
