import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/nsg_data_delete.dart';
import 'package:nsg_data/v2/base/nsg_data_source.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';
import 'package:nsg_data/v2/data_source/nsg_cached_request_params.dart';
import 'package:retry/retry.dart';

class NsgRemoteDataSource implements NsgDataSource, NsgLifecycle {
  @override
  final RetryOptions retryOptions;
  @override
  final FutureOr<bool> Function(Exception)? retryIf;
  @override
  final FutureOr<void> Function(Exception)? onRetry;
  NsgRemoteDataSource({this.retryOptions = const RetryOptions(maxAttempts: 3, maxDelay: Duration(seconds: 10)), this.retryIf, this.onRetry});

  final _cachedRequests = <String, NsgDataRequest>{};

  @override
  Future<Iterable<T>> fetchItems<T extends NsgDataItem>({
    NsgDataRequestParams? params,
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.server);

    final cachedParams = NsgCachedRequestParams(params: params ?? NsgDataRequestParams());
    _cachedRequests[cachedParams.toString()] = request;

    return await (retryOptions ?? this.retryOptions).retry(
      () => request.requestItems(filter: params ?? NsgDataRequestParams(), loadReference: loadReference?.toList()),
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
  }

  @override
  Future<T?> fetchById<T extends NsgDataItem>(
    String id, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    final prototype = NsgDataClient.client.getNewObject(T) as T;
    final filter = NsgDataRequestParams()..compare.add(name: prototype.primaryKeyField, value: id, comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.server);
    final item = await (retryOptions ?? this.retryOptions).retry(
      () => request.requestItem(filter: filter, loadReference: loadReference?.toList()),
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
    return item.isEmpty ? null : item;
  }

  @override
  Future<T> upsert<T extends NsgDataItem>(
    T item, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    item.storageType = NsgDataStorageType.server;
    final post = NsgDataPost<T>(dataItemType: T)..itemsToPost = [item];
    final saved = await (retryOptions ?? this.retryOptions).retry(
      () => post.postItem(loadReference: loadReference?.toList()),
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
    if (saved == null) {
      throw Exception('Save failed for $T');
    }
    return saved;
  }

  @override
  Future<Iterable<T>> upsertMany<T extends NsgDataItem>(
    Iterable<T> items, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    for (final item in items) {
      item.storageType = NsgDataStorageType.server;
    }
    final post = NsgDataPost<T>(dataItemType: T)..itemsToPost = items.toList();
    return await (retryOptions ?? this.retryOptions).retry(
      () => post.postItems(loadReference: loadReference?.toList()),
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
  }

  @override
  Future<void> deleteMany<T extends NsgDataItem>(
    Iterable<T> items, {
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    if (items.isEmpty) {
      return;
    }
    final delete = NsgDataDelete<T>(dataItemType: T, itemsToDelete: items.toList());
    await (retryOptions ?? this.retryOptions).retry(() => delete.deleteItems(), retryIf: retryIf ?? this.retryIf, onRetry: onRetry ?? this.onRetry);
  }

  @override
  Future<void> deleteById<T extends NsgDataItem>(
    String id, {
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    final item = await fetchById<T>(id);
    if (item != null) {
      await deleteMany<T>([item], retryOptions: retryOptions, retryIf: retryIf ?? this.retryIf, onRetry: onRetry ?? this.onRetry);
    }
  }

  @override
  Future<int> selectCount<T extends NsgDataItem>({
    NsgDataRequestParams? params,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    final cacheKey = NsgCachedRequestParams(params: params ?? NsgDataRequestParams()).toString();
    if (_cachedRequests.containsKey(cacheKey)) {
      return _cachedRequests[cacheKey]?.totalCount ?? 0;
    }

    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.server);
    final requestParams = params?.clone() ?? NsgDataRequestParams();
    requestParams.referenceList = null;
    // Если count = 0, то при большом объёме данных запрос может занимать много времени, поэтому 1
    requestParams.count = 1;
    await (retryOptions ?? this.retryOptions).retry(
      () => request.requestItems(filter: requestParams),
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
    return request.totalCount ?? 0;
  }

  @override
  FutureOr<void> dispose() {}

  @override
  FutureOr<void> init() {}
}
