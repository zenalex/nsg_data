import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/controller.dart';
import 'package:nsg_data/v2/abstract/data_source.dart';
import 'package:nsg_data/v2/abstract/lifecycle.dart';
import 'package:nsg_data/v2/controller/nsg_controller_store.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';
import 'package:nsg_data/v2/data_source/nsg_remote.dart';

mixin DataController<T extends NsgDataItem> implements Controller, Lifecycle {
  DataSource get dataSource;
  NsgControllerStore<T> get store;
  bool get disposeStore;

  @override
  NsgControllerSnapshot<T> get snapshot => store.snapshot;

  @override
  Iterable<String> get loadReference => snapshot.loadReference;

  @override
  NsgDataRequestParams get requestParams => snapshot.requestParams;

  @override
  NsgControllerStatus get status => snapshot.status;

  Stream<NsgControllerSnapshot<T>> get itemsUpdates => store.stream;

  Iterable<T> get items => snapshot.items;

  @override
  FutureOr<void> init() async {}

  @override
  FutureOr<void> dispose() async {
    if (disposeStore) {
      await store.dispose();
    }
  }
}

mixin NsgDataQueryControllerV2<T extends NsgDataItem> on DataController<T> implements QueryController<T> {
  bool get autoLoadOnInit;
  bool get useDataCache;

  bool _initialized = false;
  String _lastRequestId = '';
  Iterable<T>? _cachedItems;

  void replaceRequestParams(NsgDataRequestParams params, {Iterable<String>? loadReference}) {
    store.update(snapshot.copyWith(requestParams: params, loadReference: loadReference ?? snapshot.loadReference));
  }

  @override
  FutureOr<void> init() async {
    await super.init();
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (autoLoadOnInit) {
      await refresh();
    }
  }

  @override
  FutureOr<void> dispose() async {
    await super.dispose();
    _initialized = false;
  }

  @override
  FutureOr<Iterable<T>> load({NsgDataRequestParams? requestParams, Iterable<String>? loadReference}) async {
    if (useDataCache && _cachedItems != null && requestParams == null) {
      return _cachedItems!;
    }

    final currentRequestId = Guid.newGuid();
    _lastRequestId = currentRequestId;

    final loaded = await dataSource.fetchItems<T>(params: requestParams ?? this.requestParams, loadReference: loadReference ?? this.loadReference);

    if (_lastRequestId != currentRequestId) {
      throw NsgV2ExceptionDataObsolete();
    }

    if (useDataCache && requestParams == null) {
      _cachedItems = loaded;
    }

    return loaded;
  }

  @override
  FutureOr<void> refresh({bool Function(T item)? filter, Iterable<String>? loadReference}) async {
    store.update(snapshot.copyWith(status: NsgControllerStatus.loading, error: null));

    try {
      final loadedItems = await load(requestParams: requestParams, loadReference: loadReference ?? this.loadReference);
      final nextItems = filter == null ? loadedItems : loadedItems.where(filter);
      final count = await dataSource.selectCount<T>(params: requestParams);
      store.update(snapshot.copyWith(items: nextItems, totalCount: count, status: NsgControllerStatus.success, error: null));
    } on NsgV2ExceptionDataObsolete {
      // Ignore obsolete response.
    } on Exception catch (e) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: e));
    }
  }
}

mixin NsgDataCommandControllerV2<T extends NsgDataItem> on DataController<T> implements CommandController<T> {
  bool get _isRemoteSource => dataSource is NsgRemoteDataSource;

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
    final prototype = NsgDataClient.client.getNewObject(T) as T;
    T created;

    if (prototype.createOnServer) {
      final request = NsgDataRequest<T>(dataItemType: T, storageType: _isRemoteSource ? NsgDataStorageType.server : NsgDataStorageType.local);
      created = await request.requestItem(method: 'POST', function: '${prototype.apiRequestItems}/Create');
    } else {
      prototype.newRecordFill();
      prototype.state = NsgDataItemState.create;
      prototype.docState = NsgDataItemDocState.created;
      created = prototype;
    }

    return created;
  }

  @override
  FutureOr<Iterable<T>?> save({bool Function(T item)? filter, Iterable<String>? loadReference}) async {
    final validation = items.where(filter ?? (item) => true).map((item) => item.validateFieldValues());
    if (validation.any((result) => !result.isValid)) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: Exception('Validation failed'), validateResults: validation.toList()));
      return null;
    }

    store.update(snapshot.copyWith(status: NsgControllerStatus.loading, error: null));

    try {
      final savedItems = await dataSource.upsertMany<T>(items.where(filter ?? (item) => true), loadReference: loadReference ?? this.loadReference);
      final updatedItems = items.toList();
      for (var i = 0; i < items.length; i++) {
        try {
          updatedItems[i] = savedItems.firstWhere((savedItem) => savedItem.id == items.elementAt(i).id);
        } on StateError {
          // Ignore item not found in saved items. We just update item, that filtered
        }
      }
      store.update(snapshot.copyWith(items: updatedItems, totalCount: updatedItems.length, status: NsgControllerStatus.success, error: null));
      return savedItems;
    } on Exception catch (e) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: e));
      return null;
    }
  }

  @override
  FutureOr<void> delete({bool Function(T item)? filter}) async {
    store.update(snapshot.copyWith(status: NsgControllerStatus.loading, error: null));

    try {
      final itemsToDelete = items.where(filter ?? (item) => true).toList();
      await dataSource.deleteMany<T>(itemsToDelete);
      final deletedIds = itemsToDelete.map((e) => e.id).toSet();
      final updatedItems = items.where((item) => !deletedIds.contains(item.id)).toList();
      store.update(snapshot.copyWith(items: updatedItems, totalCount: updatedItems.length, status: NsgControllerStatus.success, error: null));
    } on Exception catch (e) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: e));
    }
  }
}

class NsgDataControllerV2<T extends NsgDataItem> with DataController<T>, NsgDataQueryControllerV2<T>, NsgDataCommandControllerV2<T> {
  @override
  final DataSource dataSource;
  @override
  final NsgControllerStore<T> store;

  @override
  final bool autoLoadOnInit;
  @override
  final bool useDataCache;
  @override
  final bool disposeStore;

  NsgDataControllerV2({required this.dataSource, required this.store, required this.autoLoadOnInit, required this.useDataCache, required this.disposeStore});
}

class NsgV2ExceptionDataObsolete implements Exception {
  @override
  String toString() => 'Data Obsolete';
}
