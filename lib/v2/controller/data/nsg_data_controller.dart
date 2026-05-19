import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/controller.dart';
import 'package:nsg_data/v2/abstract/metrica.dart';
import 'package:nsg_data/v2/base/nsg_data_source.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';
import 'package:nsg_data/v2/controller/nsg_controller_store.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';
import 'package:nsg_data/v2/controller/nsg_metrica_mixin.dart';
import 'package:nsg_data/v2/data_source/nsg_remote.dart';

mixin DataController<T extends NsgDataItem> implements Controller, NsgLifecycle, NsgMetricaMixin {
  NsgDataSource get dataSource;
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

  bool _metricaInitTracked = false;
  bool _metricaDisposeTracked = false;

  FutureOr<bool> retryIf(Exception e) async {
    // используем retryIf из dataSource, если он есть
    if (dataSource.retryIf != null && await dataSource.retryIf!(e) == false) {
      return false;
    }
    // 403 - ошибка аутентификации (Кирилл)
    if (e is NsgApiException && (e.error.code == 403)) {
      return false;
    }
    // 400 - код ошибки сервера, не предполагающий повторного запроса данных
    if (e is NsgApiException && (e.error.code == 400 || e.error.code == 401 || e.error.code == 500)) {
      return false;
    }
    return true;
  }

  FutureOr<void> onRetry(Exception e) async {
    trackMetricaRetry(e);
    // используем onRetry из dataSource, если он есть
    if (dataSource.onRetry != null) {
      await dataSource.onRetry!(e);
    }
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
    if (disposeStore) {
      await store.dispose();
    }
    if (_metricaDisposeTracked) {
      return;
    }
    _metricaDisposeTracked = true;
    trackMetricaDispose();
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

    final loaded = await dataSource.fetchItems<T>(
      params: requestParams ?? this.requestParams,
      loadReference: loadReference ?? this.loadReference,
      retryIf: retryIf,
      onRetry: onRetry,
    );

    if (_lastRequestId != currentRequestId) {
      throw NsgV2ExceptionDataObsolete();
    }

    if (useDataCache && requestParams == null) {
      _cachedItems = loaded;
    }

    return loaded;
  }

  @override
  FutureOr<void> refresh({Iterable<T>? items, Iterable<String>? loadReference, NsgDataRequestParams? requestParams}) async {
    store.update(snapshot.copyWith(status: NsgControllerStatus.loading, error: null));

    final sw = Stopwatch()..start();
    try {
      final loadedItems = await load(requestParams: requestParams ?? this.requestParams, loadReference: loadReference ?? this.loadReference);
      final nextItems = items != null ? loadedItems.where((item) => items.contains(item)) : loadedItems;
      final countParams = requestParams ?? this.requestParams;
      // Count uses the same filter as load; heavy OR/IN filters may fail on SQL Server.
      var count = nextItems.length;
      try {
        count = await dataSource.selectCount<T>(params: countParams);
      } on Exception {
        // Keep items from a successful load; use loaded length as a safe fallback.
      }
      store.update(snapshot.copyWith(items: nextItems, totalCount: count, status: NsgControllerStatus.success, error: null));
      trackMetricaLoad(itemCount: nextItems.length, durationMs: sw.elapsedMilliseconds);
    } on NsgV2ExceptionDataObsolete {
      // Ignore obsolete response.
    } on Exception catch (e, st) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: e));
      trackMetricaError(e, st);
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
  FutureOr<Iterable<T>?> save({Iterable<T>? items, Iterable<String>? loadReference}) async {
    final validation = items?.map((item) => item.validateFieldValues()) ?? this.items.map((item) => item.validateFieldValues());
    if (validation.any((result) => !result.isValid)) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: Exception('Validation failed'), validateResults: validation.toList()));
      return null;
    }

    store.update(snapshot.copyWith(status: NsgControllerStatus.loading, error: null));

    final sw = Stopwatch()..start();
    try {
      final savedItems = await dataSource.upsertMany<T>(
        items?.where((item) => true) ?? this.items.where((item) => true),
        loadReference: loadReference ?? this.loadReference,
        retryIf: retryIf,
        onRetry: onRetry,
      );
      // Always start from the full snapshot so a partial save (e.g. saveSelected)
      // does not replace the entire list with only the saved subset.
      final updatedItems = snapshot.items.toList();
      for (var i = 0; i < updatedItems.length; i++) {
        try {
          updatedItems[i] = savedItems.firstWhere((savedItem) => savedItem.id == updatedItems[i].id);
        } on StateError {
          // Item is not in the saved subset — keep the existing snapshot value.
        }
      }
      // Add items returned by the server that are not yet present in the snapshot
      // (e.g. a new item whose server-assigned ID differs from the client-side ID).
      final snapshotIds = updatedItems.map((e) => e.id).toSet();
      for (final savedItem in savedItems) {
        if (!snapshotIds.contains(savedItem.id)) {
          updatedItems.add(savedItem);
        }
      }
      store.update(snapshot.copyWith(items: updatedItems, totalCount: updatedItems.length, status: NsgControllerStatus.success, error: null));
      trackMetricaSave(itemCount: savedItems.length, durationMs: sw.elapsedMilliseconds);
      return savedItems;
    } on Exception catch (e, st) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: e));
      trackMetricaError(e, st);
      return null;
    }
  }

  @override
  FutureOr<void> delete({Iterable<T>? items}) async {
    store.update(snapshot.copyWith(status: NsgControllerStatus.loading, error: null));

    try {
      final itemsToDelete = items?.toList() ?? this.items.toList();
      await dataSource.deleteMany<T>(itemsToDelete, retryIf: retryIf, onRetry: onRetry);
      final deletedIds = itemsToDelete.map((e) => e.id).toSet();
      // Always filter from the full snapshot, not from the `items` parameter, so
      // a partial delete does not wipe the rest of the list.
      final updatedItems = this.items.where((item) => !deletedIds.contains(item.id)).toList();
      store.update(snapshot.copyWith(items: updatedItems, totalCount: updatedItems.length, status: NsgControllerStatus.success, error: null));
      trackMetricaDelete(itemCount: itemsToDelete.length);
    } on Exception catch (e, st) {
      store.update(snapshot.copyWith(status: NsgControllerStatus.error, error: e));
      trackMetricaError(e, st);
    }
  }
}

class NsgDataControllerV2<T extends NsgDataItem> with DataController<T>, NsgDataQueryControllerV2<T>, NsgDataCommandControllerV2<T>, NsgMetricaMixin {
  @override
  final NsgDataSource dataSource;
  @override
  final NsgControllerStore<T> store;

  @override
  final bool autoLoadOnInit;
  @override
  final bool useDataCache;
  @override
  final bool disposeStore;

  @override
  final Metrica? metrica;

  NsgDataControllerV2({
    required this.dataSource,
    NsgControllerStore<T>? store,
    this.autoLoadOnInit = false,
    this.useDataCache = false,
    this.disposeStore = true,
    this.metrica,
  }) : store = store ?? NsgControllerStore<T>();
}

class NsgV2ExceptionDataObsolete implements Exception {
  @override
  String toString() => 'Data Obsolete';
}
