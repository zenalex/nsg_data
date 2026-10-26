import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nsg_data/nsg_data.dart';

class _Item extends NsgDataItem {
  @override
  String get typeName => 'SelectedRefreshOwnerItem';
  @override
  void initialize() {
    addField(NsgDataStringField('id'), primaryKey: true);
    addField(NsgDataStringField('name'));
  }

  @override
  NsgDataItem getNewObject() => _Item();
  @override
  String get id => getFieldValue('id').toString();
  @override
  set id(String value) => setFieldValue('id', value);
  String get name => getFieldValue('name').toString();
  set name(String value) => setFieldValue('name', value);
}

class _Store extends NsgDataController<_Item> {
  _Store() {
    requestOnInit = false;
  }
  final reads = <Completer<NsgDataItem>>[];
  int hooks = 0;
  Completer<void>? hookEntered, hookExit;
  @override
  Future<NsgDataItem> refreshItem(
    NsgDataItem item,
    List<String>? references, {
    bool changeStatus = false,
  }) {
    final read = Completer<NsgDataItem>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<void> afterRefreshItem(
    NsgDataItem item,
    List<String>? references,
  ) async {
    hooks++;
    hookEntered?.complete();
    await hookExit?.future;
  }
}

_Item _item(String id, [String? name]) => _Item()
  ..id = id
  ..name = name ?? id;
Future<void> _start(_Store store, _Item target, bool setSelected) async {
  if (setSelected) {
    await store.setAndRefreshSelectedItem(target, null);
  } else {
    store.selectedItem = target;
    await store.refreshCurrentItem();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => NsgDataClient.client.registerDataItem(_Item()));
  for (final setSelected in [true, false]) {
    final method = setSelected
        ? 'setAndRefreshSelectedItem'
        : 'refreshCurrentItem';
    test(
      '$method: discarded A leaves B untouched and clears loading',
      () async {
        final store = _Store(), a = _item('A'), b = _item('B');
        final pending = _start(store, a, setSelected);
        expect(store.currentStatus.isLoading, isTrue);
        store.selectedItem = b;
        store.backupItem = b;
        store.reads.single.complete(_item('A', 'obsolete'));
        await pending;
        expect(identical(store.selectedItem, b), isTrue);
        expect(store.currentItem.name, 'B');
        expect(identical(store.backupItem, b), isTrue);
        expect(store.currentStatus.isSuccess, isTrue);
        expect(store.hooks, 0);
      },
    );
    test('$method: setter A -> B -> same A accepts its valid answer', () async {
      final store = _Store(), a = _item('A');
      final pending = _start(store, a, setSelected);
      store.selectedItem = _item('B');
      store.selectedItem = a;
      store.reads.single.complete(_item('A', 'fresh A'));
      await pending;
      expect(store.currentItem.id, 'A');
      expect(store.currentItem.name, 'fresh A');
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.hooks, setSelected ? 1 : 0);
    });
    test(
      '$method: null selection is not resurrected or left loading',
      () async {
        final store = _Store();
        final pending = _start(store, _item('A'), setSelected);
        store.selectedItem = null;
        store.reads.single.complete(_item('A', 'obsolete'));
        await pending;
        expect(store.selectedItem, isNull);
        expect(store.backupItem, isNull);
        expect(store.hooks, 0);
        expect(store.currentStatus.isSuccess, isTrue);
      },
    );
    test(
      '$method: news-like repeated same-id replacements do not hang loading',
      () async {
        final store = _Store();
        final pending = _start(store, _item('A'), setSelected);
        for (var i = 0; i < 3; i++) {
          store.selectedItem = _item('A', 'poll$i');
        }
        final selected = store.selectedItem;
        store.reads.single.complete(_item('A', 'obsolete'));
        await pending;
        expect(identical(store.selectedItem, selected), isTrue);
        expect(store.currentItem.name, 'poll2');
        expect(store.hooks, 0);
        expect(store.currentStatus.isSuccess, isTrue);
      },
    );
    test('$method: in-place id change discards A and clears loading', () async {
      final store = _Store(), a = _item('A');
      final pending = _start(store, a, setSelected);
      a.id = 'B';
      a.name = 'B';
      store.reads.single.complete(_item('A', 'obsolete'));
      await pending;
      expect(store.currentItem.id, 'B');
      expect(store.currentItem.name, 'B');
      expect(store.currentStatus.isSuccess, isTrue);
    });
    test('$method: late exception preserves B and clears loading', () async {
      final store = _Store(), b = _item('B');
      final pending = _start(store, _item('A'), setSelected);
      store.selectedItem = b;
      store.backupItem = b;
      final checked = expectLater(
        pending,
        setSelected ? completes : throwsA(isA<Exception>()),
      );
      store.reads.single.completeError(Exception('obsolete failure'));
      await checked;
      expect(identical(store.selectedItem, b), isTrue);
      expect(identical(store.backupItem, b), isTrue);
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.hooks, 0);
    });
    test('$method: late Error is rethrown without leaving B loading', () async {
      final store = _Store(), b = _item('B');
      final pending = _start(store, _item('A'), setSelected);
      store.selectedItem = b;
      final checked = expectLater(pending, throwsA(isA<StateError>()));
      store.reads.single.completeError(StateError('obsolete failure'));
      await checked;
      expect(identical(store.selectedItem, b), isTrue);
      expect(store.currentStatus.isSuccess, isTrue);
    });
    test('$method: ordinary owned response still applies', () async {
      final store = _Store();
      final pending = _start(store, _item('A'), setSelected);
      store.reads.single.complete(_item('A', 'fresh'));
      await pending;
      expect(store.currentItem.id, 'A');
      expect(store.currentItem.name, 'fresh');
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.hooks, setSelected ? 1 : 0);
    });
    for (final secondFirst in [true, false]) {
      test(
        '$method: same-instance reads both apply, secondFirst=$secondFirst',
        () async {
          final store = _Store(), a = _item('A');
          final first = _start(store, a, setSelected),
              second = _start(store, a, setSelected);
          if (secondFirst) {
            store.reads[1].complete(_item('A', 'second'));
            await second;
            store.reads[0].complete(_item('A', 'first'));
            await first;
          } else {
            store.reads[0].complete(_item('A', 'first'));
            await first;
            store.reads[1].complete(_item('A', 'second'));
            await second;
          }
          expect(store.currentItem.name, secondFirst ? 'first' : 'second');
          expect(store.currentStatus.isSuccess, isTrue);
          expect(store.hooks, setSelected ? 2 : 0);
        },
      );
    }
    test(
      '$method: A -> B -> A refresh invocations retain only the last owner',
      () async {
        final store = _Store(), a = _item('A');
        final first = _start(store, a, setSelected),
            middle = _start(store, _item('B'), setSelected),
            last = _start(store, a, setSelected);
        store.reads[0].complete(_item('A', 'old A'));
        await first;
        expect(store.currentStatus.isLoading, isTrue);
        store.reads[1].complete(_item('B', 'old B'));
        await middle;
        expect(store.currentStatus.isLoading, isTrue);
        store.reads[2].complete(_item('A', 'new A'));
        await last;
        expect(store.currentItem.name, 'new A');
        expect(store.currentStatus.isSuccess, isTrue);
        expect(store.hooks, setSelected ? 1 : 0);
      },
    );
    test('$method: old response cannot finish newer B loading', () async {
      final store = _Store();
      final first = _start(store, _item('A'), setSelected),
          second = _start(store, _item('B'), setSelected);
      store.reads[0].complete(_item('A', 'old A'));
      await first;
      expect(store.currentItem.id, 'B');
      expect(store.currentStatus.isLoading, isTrue);
      store.reads[1].complete(_item('B', 'fresh B'));
      await second;
      expect(store.currentItem.name, 'fresh B');
      expect(store.currentStatus.isSuccess, isTrue);
    });
    test('$method: late exception cannot finish newer B loading', () async {
      final store = _Store();
      final first = _start(store, _item('A'), setSelected),
          second = _start(store, _item('B'), setSelected);
      final checked = expectLater(
        first,
        setSelected ? completes : throwsA(isA<Exception>()),
      );
      store.reads[0].completeError(Exception('old A'));
      await checked;
      expect(store.currentItem.id, 'B');
      expect(store.currentStatus.isLoading, isTrue);
      store.reads[1].complete(_item('B', 'fresh B'));
      await second;
      expect(store.currentStatus.isSuccess, isTrue);
    });
  }
  for (final setFirst in [true, false]) {
    for (final secondFirst in [true, false]) {
      test(
        'mixed same-instance methods preserve list backup and hook, setFirst=$setFirst secondFirst=$secondFirst',
        () async {
          final store = _Store(), a = _item('A');
          store.dataItemList = [a];
          final first = _start(store, a, setFirst),
              second = _start(store, a, !setFirst);
          if (secondFirst) {
            store.reads[1].complete(_item('A', 'second'));
            await second;
            store.reads[0].complete(_item('A', 'first'));
            await first;
          } else {
            store.reads[0].complete(_item('A', 'first'));
            await first;
            store.reads[1].complete(_item('A', 'second'));
            await second;
          }
          expect(store.currentItem.name, secondFirst ? 'first' : 'second');
          expect(store.hooks, 1);
          expect(store.currentStatus.isSuccess, isTrue);
          final setName = setFirst ? 'first' : 'second';
          expect((store.backupItem as _Item).name, setName);
          // Поздний refreshCurrentItem заменяет выбранный объект, но не должен
          // стирать учёт списка, сделанный setAndRefreshSelectedItem.
          expect(store.dataItemList.single.id, 'A');
          expect(store.dataItemList.single.getFieldValue('name'), setName);
        },
      );
    }
  }
  test(
    'own replacement followed by setter B -> original A keeps the valid A read',
    () async {
      final store = _Store(), a = _item('A');
      final setting = _start(store, a, true),
          refreshing = _start(store, a, false);
      store.reads[1].complete(_item('A', 'own replacement'));
      await refreshing;
      store.selectedItem = _item('B');
      store.selectedItem = a;
      store.reads[0].complete(_item('A', 'valid A'));
      await setting;
      expect(store.currentItem.name, 'valid A');
      expect(store.hooks, 1);
      expect(store.currentStatus.isSuccess, isTrue);
    },
  );
  for (final failHook in [false, true]) {
    test(
      'selection change during afterRefreshItem clears loading, failure=$failHook',
      () async {
        final store = _Store()
          ..hookEntered = Completer<void>()
          ..hookExit = Completer<void>();
        final pending = _start(store, _item('A'), true);
        store.reads.single.complete(_item('A', 'fresh A'));
        await store.hookEntered!.future;
        final b = _item('B');
        store.selectedItem = b;
        store.backupItem = b;
        if (failHook) {
          store.hookExit!.completeError(Exception('late hook'));
        } else {
          store.hookExit!.complete();
        }
        await pending;
        expect(identical(store.selectedItem, b), isTrue);
        expect(identical(store.backupItem, b), isTrue);
        expect(store.currentStatus.isSuccess, isTrue);
      },
    );
  }
  test('owned setAndRefresh exception retains ordinary error status', () async {
    final store = _Store(), a = _item('A');
    final pending = _start(store, a, true);
    store.reads.single.completeError(Exception('owned failure'));
    await pending;
    expect(identical(store.selectedItem, a), isTrue);
    expect(store.currentStatus.isError, isTrue);
  });
}
