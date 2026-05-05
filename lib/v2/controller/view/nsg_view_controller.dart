import 'dart:async';
import 'package:async/async.dart';

import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/lifecycle.dart';
import 'package:nsg_data/v2/abstract/controller.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/data/nsg_data_controller.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';
import 'package:nsg_data/v2/controller/nsg_controller_store.dart';

mixin ViewController<T extends NsgDataItem> implements Lifecycle, Controller {
  /// Full data controller (query + command). One getter avoids conflicting
  /// overrides in [NsgViewQueryControllerV2] vs [NsgViewCommandControllerV2].
  NsgDataControllerV2<T> get dataController;
  NsgControllerStore<T> get selectedStore;
  NsgControllerStore<T> get backupStore;

  @override
  NsgControllerSnapshot<T> get snapshot => dataController.snapshot;

  @override
  Iterable<String> get loadReference => snapshot.loadReference;

  @override
  NsgDataRequestParams get requestParams => snapshot.requestParams;

  @override
  NsgControllerStatus get status => dataController.status;

  Iterable<T> get items => snapshot.items;
  Stream<NsgControllerSnapshot<T>> get itemsUpdates => dataController.itemsUpdates;

  NsgControllerSnapshot<T> get selectedSnapshot => selectedStore.snapshot;
  Iterable<T> get selectedItems => selectedSnapshot.items;
  Stream<NsgControllerSnapshot<T>> get selectedItemsUpdates => selectedStore.stream;
  NsgControllerStatus get selectedStatus => selectedSnapshot.status;

  NsgControllerSnapshot<T> get backupSnapshot => backupStore.snapshot;
  Iterable<T> get backupItems => backupSnapshot.items;
  Stream<NsgControllerSnapshot<T>> get backupItemsUpdates => backupStore.stream;
  NsgControllerStatus get backupStatus => backupSnapshot.status;

  T? get selectedItem => selectedItems.isEmpty ? null : selectedItems.first;
  set selectedItem(T? item) {
    selectedStore.update(selectedSnapshot.copyWith(items: item == null ? <T>[] : <T>[item], totalCount: item == null ? 0 : 1));
  }

  T? get backupItem => backupItems.isEmpty ? null : backupItems.first;
  set backupItem(T? item) {
    backupStore.update(backupSnapshot.copyWith(items: item == null ? <T>[] : <T>[item], totalCount: item == null ? 0 : 1));
  }

  bool get isModified {
    final selected = selectedItem;
    final backup = backupItem;
    if (selected == null || backup == null) {
      return false;
    }
    return !selected.isEqual(backup);
  }

  void select(T? item, {bool saveAsBackup = false}) {
    selectedItem = item;
    if (saveAsBackup) {
      backupItem = item == null ? null : (item.clone() as T);
    }
  }

  void saveBackup(T item) {
    selectedItem = item;
    backupItem = item.clone() as T;
  }

  void restoreFromBackup() {
    final backup = backupItem;
    if (backup == null) {
      return;
    }
    selectedItem = backup.clone() as T;
  }

  @override
  FutureOr<void> init() async {}

  @override
  FutureOr<void> dispose() async {
    await selectedStore.dispose();
    await backupStore.dispose();
  }

  Widget observeStatus({
    Iterable<Stream<NsgControllerSnapshot<T>>>? listenables,
    Widget Function(BuildContext context, NsgControllerSnapshot<T> snapshot)? builder,
  }) {
    return StreamBuilder<NsgControllerSnapshot<T>>(
      stream: StreamGroup.merge(listenables ?? [itemsUpdates, selectedItemsUpdates, backupItemsUpdates]),
      builder: (context, snapshot) {
        return builder?.call(context, snapshot.data ?? dataController.snapshot) ?? const SizedBox.shrink();
      },
    );
  }
}

mixin NsgViewQueryControllerV2<T extends NsgDataItem> on ViewController<T> implements QueryController<T> {
  bool _initialized = false;
  bool refreshOnInit = false;

  @override
  FutureOr<void> init() async {
    await super.init();
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (refreshOnInit) {
      await dataController.refresh();
    }
  }

  @override
  FutureOr<void> dispose() async {
    await super.dispose();
    _initialized = false;
  }

  @override
  FutureOr<Iterable<T>> load({NsgDataRequestParams? requestParams, Iterable<String>? loadReference}) async {
    return dataController.load(requestParams: requestParams ?? this.requestParams, loadReference: loadReference ?? this.loadReference);
  }

  @override
  FutureOr<void> refresh({bool Function(T item)? filter, Iterable<String>? loadReference}) async {
    return dataController.refresh(filter: filter, loadReference: loadReference ?? this.loadReference);
  }
}

mixin NsgViewCommandControllerV2<T extends NsgDataItem> on ViewController<T> implements CommandController<T> {
  @override
  FutureOr<void> init() async {
    await super.init();
  }

  @override
  FutureOr<void> dispose() async {
    await super.dispose();
  }

  @override
  FutureOr<T> create() async {
    return dataController.create();
  }

  FutureOr<T> createAndSelect({bool saveAsBackup = true}) async {
    final created = await create();
    selectedItem = created.clone() as T;
    if (saveAsBackup) {
      backupItem = selectedItem == null ? null : (selectedItem!.clone() as T);
    }
    return created;
  }

  @override
  FutureOr<Iterable<T>?> save({bool Function(T item)? filter, Iterable<String>? loadReference}) async {
    return dataController.save(filter: filter, loadReference: loadReference ?? this.loadReference);
  }

  FutureOr<T?> saveSelected({Iterable<String>? loadReference}) async {
    final selected = selectedItem;
    if (selected == null) {
      return null;
    }

    // Keep selected item inside data store before save pipeline.
    final mergedItems = items.toList();
    final selectedIndex = mergedItems.indexWhere((e) => e.id == selected.id);
    if (selectedIndex >= 0) {
      mergedItems[selectedIndex] = selected;
    } else {
      mergedItems.add(selected);
    }
    dataController.store.update(dataController.snapshot.copyWith(items: mergedItems, totalCount: mergedItems.length));

    final saved = await save(filter: (item) => item.id == selected.id, loadReference: loadReference);
    if (saved == null || saved.isEmpty) {
      return null;
    }
    final savedItem = saved.first;
    selectedItem = savedItem;
    backupItem = savedItem.clone() as T;
    return savedItem;
  }

  @override
  FutureOr<void> delete({bool Function(T item)? filter}) async {
    dataController.delete(filter: filter);
  }

  FutureOr<void> deleteSelected() async {
    final selected = selectedItem;
    if (selected == null) {
      return;
    }
    await delete(filter: (item) => item.id == selected.id);
    selectedItem = null;
    backupItem = null;
  }
}

class NsgViewControllerV2<T extends NsgDataItem> with ViewController<T>, NsgViewQueryControllerV2<T>, NsgViewCommandControllerV2<T> {
  @override
  final NsgControllerStore<T> backupStore;

  @override
  final NsgControllerStore<T> selectedStore;

  @override
  final NsgDataControllerV2<T> dataController;

  NsgViewControllerV2({required this.dataController, required this.selectedStore, required this.backupStore, bool refreshOnInit = false}) {
    this.refreshOnInit = refreshOnInit;
  }
}
