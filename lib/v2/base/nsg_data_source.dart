import 'dart:async';

import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/nsg_data_requestParams.dart';
import 'package:nsg_data/v2/abstract/data_source.dart';
import 'package:retry/retry.dart';

abstract interface class NsgDataSource implements DataSource {
  RetryOptions get retryOptions;

  FutureOr<bool> Function(Exception)? get retryIf;

  FutureOr<void> Function(Exception)? get onRetry;
  @override
  FutureOr<Iterable<T>> fetchItems<T extends NsgDataItem>({
    NsgDataRequestParams? params,
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });

  @override
  FutureOr<T?> fetchById<T extends NsgDataItem>(
    String id, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });

  @override
  FutureOr<T> upsert<T extends NsgDataItem>(
    T item, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });

  @override
  FutureOr<Iterable<T>> upsertMany<T extends NsgDataItem>(
    Iterable<T> items, {
    Iterable<String>? loadReference,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });

  @override
  FutureOr<void> deleteMany<T extends NsgDataItem>(
    Iterable<T> items, {
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });

  @override
  FutureOr<void> deleteById<T extends NsgDataItem>(
    String id, {
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });

  @override
  FutureOr<int> selectCount<T extends NsgDataItem>({
    NsgDataRequestParams? params,
    RetryOptions? retryOptions,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  });
}
