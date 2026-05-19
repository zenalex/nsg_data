import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/base/nsg_data_source.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';
import 'package:nsg_data/v2/data_source/nsg_cached_request_params.dart';
import 'package:retry/retry.dart';

class NsgLocalDataSource implements NsgDataSource, NsgLifecycle {
  @override
  final RetryOptions retryOptions;
  @override
  final FutureOr<bool> Function(Exception)? retryIf;
  @override
  final FutureOr<void> Function(Exception)? onRetry;
  NsgLocalDataSource({this.retryOptions = const RetryOptions(maxAttempts: 3, maxDelay: Duration(seconds: 10)), this.retryIf, this.onRetry});

  final _cachedRequests = <String, NsgDataRequest>{};

  @override
  Future<Iterable<T>> fetchItems<T extends NsgDataItem>({
    NsgDataRequestParams? params,
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.local);

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
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.local);
    return await (retryOptions ?? this.retryOptions).retry(
      () async {
        final item = await request.requestItem(filter: filter, loadReference: loadReference?.toList());
        return item.isEmpty ? null : item;
      },
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
  }

  @override
  Future<T> upsert<T extends NsgDataItem>(
    T item, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    item.storageType = NsgDataStorageType.local;
    await (retryOptions ?? this.retryOptions).retry(
      () async {
        await NsgLocalDb.instance.postItems([item]);
        return item;
      },
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
    return item;
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
      item.storageType = NsgDataStorageType.local;
    }
    await (retryOptions ?? this.retryOptions).retry(
      () async {
        await NsgLocalDb.instance.postItems(items.cast<NsgDataItem>().toList());
        return items;
      },
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
    return items;
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
    await (retryOptions ?? this.retryOptions).retry(
      () async {
        await NsgLocalDb.instance.deleteItems(items.cast<NsgDataItem>().toList());
      },
      retryIf: retryIf ?? this.retryIf,
      onRetry: onRetry ?? this.onRetry,
    );
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
      await (retryOptions ?? this.retryOptions).retry(
        () async {
          await deleteMany<T>([item]);
        },
        retryIf: retryIf ?? this.retryIf,
        onRetry: onRetry ?? this.onRetry,
      );
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

    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.local);
    final requestParams = params?.clone() ?? NsgDataRequestParams();
    requestParams.referenceList = [];
    requestParams.count = 0;
    await (retryOptions ?? this.retryOptions).retry(
      () async {
        await request.requestItems(filter: requestParams);
        return request.totalCount ?? 0;
      },
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
