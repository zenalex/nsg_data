import 'dart:async';
import 'package:async/async.dart';

import 'package:flutter/material.dart';
import 'package:nsg_data/controllers/nsg_controller_regime.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/controller.dart';
import 'package:nsg_data/v2/abstract/metrica.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/data/nsg_data_controller.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';
import 'package:nsg_data/v2/controller/nsg_controller_store.dart';
import 'package:nsg_data/v2/controller/nsg_metrica_mixin.dart';
import 'package:nsg_data/v2/metrica/nsg_metrica_events.dart';

mixin ViewController<T extends NsgDataItem> implements NsgLifecycle, Controller, NsgMetricaMixin {
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

  NsgControllerRegime get regime;

  bool _metricaInitTracked = false;
  bool _metricaDisposeTracked = false;

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
    if (item != null) {
      trackEvent(NsgMetricaUserActionEvent(
        action: 'select',
        target: metricaControllerKey,
        extraParams: {'item_id': item.id},
      ));
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
  FutureOr<void> init() async {
    if (_metricaInitTracked) {
      return;
    }
    _metricaInitTracked = true;
    trackMetricaInit();
  }

  @override
  FutureOr<void> dispose() async {
    await selectedStore.dispose();
    await backupStore.dispose();
    if (_metricaDisposeTracked) {
      return;
    }
    _metricaDisposeTracked = true;
    trackMetricaDispose();
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
  bool get refreshOnInit;

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
  FutureOr<void> refresh({Iterable<T>? items, Iterable<String>? loadReference, NsgDataRequestParams? requestParams}) async {
    return dataController.refresh(items: items, loadReference: loadReference ?? this.loadReference, requestParams: requestParams ?? this.requestParams);
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
    trackEvent(NsgMetricaUserActionEvent(
      action: 'create_and_select',
      target: metricaControllerKey,
    ));
    return created;
  }

  @override
  FutureOr<Iterable<T>?> save({Iterable<T>? items, Iterable<String>? loadReference}) async {
    return dataController.save(items: items, loadReference: loadReference ?? this.loadReference);
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

    final saved = await save(items: [selected], loadReference: loadReference);
    if (saved == null || saved.isEmpty) {
      return null;
    }
    final savedItem = saved.first;
    selectedItem = savedItem;
    backupItem = savedItem.clone() as T;
    return savedItem;
  }

  @override
  FutureOr<void> delete({Iterable<T>? items}) async {
    await dataController.delete(items: items);
  }

  FutureOr<void> deleteSelected() async {
    final selected = selectedItem;
    if (selected == null) {
      return;
    }
    await delete(items: [selected]);
    selectedItem = null;
    backupItem = null;
  }
}

class NsgViewControllerV2<T extends NsgDataItem> with ViewController<T>, NsgViewQueryControllerV2<T>, NsgViewCommandControllerV2<T>, NsgMetricaMixin {
  @override
  final NsgControllerStore<T> backupStore;

  @override
  final NsgControllerStore<T> selectedStore;

  @override
  final NsgDataControllerV2<T> dataController;

  @override
  final bool refreshOnInit;

  @override
  NsgControllerRegime regime;

  /// Analytics service. When `null`, tracking is silently disabled.
  /// Defaults to [dataController.metrica] so that a single [Metrica]
  /// instance covers both the data and view layers.
  @override
  Metrica? get metrica => _metrica ?? dataController.metrica;
  final Metrica? _metrica;

  NsgViewControllerV2({
    required this.dataController,
    NsgControllerStore<T>? selectedStore,
    NsgControllerStore<T>? backupStore,
    this.refreshOnInit = false,
    this.regime = NsgControllerRegime.view,
    Metrica? metrica,
  })  : selectedStore = selectedStore ?? NsgControllerStore<T>(),
        backupStore = backupStore ?? NsgControllerStore<T>(),
        _metrica = metrica;
}
