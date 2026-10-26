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
    List<String>? referenceList, {
    bool changeStatus = false,
  }) {
    final read = Completer<NsgDataItem>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<void> afterRefreshItem(
    NsgDataItem item,
    List<String>? referenceList,
  ) async {
    hooks++;
    hookEntered?.complete();
    await hookExit?.future;
  }

  void ready() {
    currentStatus = GetStatus.success(NsgBaseController.emptyData);
    status = GetStatus.success(NsgBaseController.emptyData);
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
    test('$method: A response cannot overwrite B', () async {
      final store = _Store(), a = _item('A'), b = _item('B');
      final pending = _start(store, a, setSelected);
      store.selectedItem = b;
      store.backupItem = b;
      store.ready();
      store.reads.single.complete(_item('A', 'late A'));
      await pending;
      expect(identical(store.selectedItem, b), isTrue);
      expect(store.currentItem.id, 'B');
      expect(store.currentItem.name, 'B');
      expect(identical(store.backupItem, b), isTrue);
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.hooks, 0);
      expect(store.selectedItemChanged.subscriberCount, 0);
    });
    test('$method: A -> B -> original A cancels the old A request', () async {
      final store = _Store(), a = _item('A');
      final pending = _start(store, a, setSelected);
      store.selectedItem = _item('B');
      store.selectedItem = a;
      store.ready();
      store.reads.single.complete(_item('A', 'obsolete A'));
      await pending;
      expect(identical(store.selectedItem, a), isTrue);
      expect(store.currentItem.name, 'A');
      expect(store.hooks, 0);
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.selectedItemChanged.subscriberCount, 0);
    });
    test('$method: null selection is not resurrected', () async {
      final store = _Store();
      final pending = _start(store, _item('A'), setSelected);
      store.selectedItem = null;
      store.ready();
      store.reads.single.complete(_item('A', 'late A'));
      await pending;
      expect(store.selectedItem, isNull);
      expect(store.backupItem, isNull);
      expect(store.hooks, 0);
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.selectedItemChanged.subscriberCount, 0);
    });
    test(
      '$method: same id on a new selection object stays untouched',
      () async {
        final store = _Store();
        final pending = _start(store, _item('A'), setSelected);
        final newSelection = _item('A', 'new selection');
        store.selectedItem = newSelection;
        store.ready();
        store.reads.single.complete(_item('A', 'obsolete'));
        await pending;
        expect(identical(store.selectedItem, newSelection), isTrue);
        expect(store.currentItem.name, 'new selection');
        expect(store.hooks, 0);
        expect(store.selectedItemChanged.subscriberCount, 0);
      },
    );
    test('$method: in-place id change invalidates the request', () async {
      final store = _Store(), a = _item('A');
      final pending = _start(store, a, setSelected);
      a.id = 'B';
      a.name = 'B';
      store.ready();
      store.reads.single.complete(_item('A', 'obsolete'));
      await pending;
      expect(store.currentItem.id, 'B');
      expect(store.currentItem.name, 'B');
      expect(store.selectedItemChanged.subscriberCount, 0);
    });
    test('$method: late exception preserves B and its ready status', () async {
      final store = _Store(), b = _item('B');
      final pending = _start(store, _item('A'), setSelected);
      store.selectedItem = b;
      store.backupItem = b;
      store.ready();
      final checked = expectLater(
        pending,
        setSelected ? completes : throwsA(isA<Exception>()),
      );
      store.reads.single.completeError(Exception('obsolete request failure'));
      await checked;
      expect(identical(store.selectedItem, b), isTrue);
      expect(identical(store.backupItem, b), isTrue);
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.hooks, 0);
      expect(store.selectedItemChanged.subscriberCount, 0);
    });
    test('$method: ordinary owned response still applies', () async {
      final store = _Store(), a = _item('A');
      final pending = _start(store, a, setSelected);
      store.reads.single.complete(_item('A', 'fresh'));
      await pending;
      expect(store.currentItem.id, 'A');
      expect(store.currentItem.name, 'fresh');
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.hooks, setSelected ? 1 : 0);
      expect(store.selectedItemChanged.subscriberCount, 0);
    });
    for (final newerFirst in [true, false]) {
      test(
        '$method: latest same-match request wins, newerFirst=$newerFirst',
        () async {
          final store = _Store(), a = _item('A');
          final first = _start(store, a, setSelected),
              second = _start(store, a, setSelected);
          if (newerFirst) {
            store.reads[1].complete(_item('A', 'newer'));
            await second;
            store.reads[0].complete(_item('A', 'older'));
            await first;
          } else {
            store.reads[0].complete(_item('A', 'older'));
            await first;
            expect(store.currentStatus.isLoading, isTrue);
            store.reads[1].complete(_item('A', 'newer'));
            await second;
          }
          expect(store.currentItem.name, 'newer');
          expect(store.currentStatus.isSuccess, isTrue);
          expect(store.selectedItemChanged.subscriberCount, 0);
        },
      );
    }
  }
  test(
    'setAndRefresh: navigation during afterRefreshItem prevents stale completion',
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
      store.ready();
      store.hookExit!.complete();
      await pending;
      expect(identical(store.selectedItem, b), isTrue);
      expect(identical(store.backupItem, b), isTrue);
      expect(store.currentStatus.isSuccess, isTrue);
      expect(store.selectedItemChanged.subscriberCount, 0);
    },
  );
  test(
    'setAndRefresh: owned exception retains the ordinary error status',
    () async {
      final store = _Store(), a = _item('A');
      final pending = _start(store, a, true);
      store.reads.single.completeError(Exception('owned failure'));
      await pending;
      expect(identical(store.selectedItem, a), isTrue);
      expect(store.currentStatus.isError, isTrue);
      expect(store.selectedItemChanged.subscriberCount, 0);
    },
  );
}
