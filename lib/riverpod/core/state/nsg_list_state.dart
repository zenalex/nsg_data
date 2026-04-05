import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/riverpod/core/query/nsg_list_query.dart';

const Object _sentinel = Object();

class NsgListState<T extends NsgDataItem> {
  final UnmodifiableListView<T> items;
  final NsgListQuery query;
  final String? selectedId;
  final int? totalCount;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Object? error;
  final StackTrace? stackTrace;

  NsgListState({
    Iterable<T> items = const [],
    NsgListQuery? query,
    this.selectedId,
    this.totalCount,
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.stackTrace,
  }) : query = query ?? NsgListQuery(),
       items = UnmodifiableListView<T>(items.map((e) => e.clone() as T));

  NsgListState._trusted({
    required this.items,
    required this.query,
    required this.selectedId,
    required this.totalCount,
    required this.hasMore,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.error,
    required this.stackTrace,
  });

  T? get selectedItem {
    if (selectedId == null) return null;
    for (final item in items) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  bool get hasError => error != null;
  bool get isEmpty => items.isEmpty;
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;

  NsgListState<T> copyWith({
    Iterable<T>? items,
    NsgListQuery? query,
    Object? selectedId = _sentinel,
    Object? totalCount = _sentinel,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _sentinel,
    Object? stackTrace = _sentinel,
  }) {
    return NsgListState<T>._trusted(
      items: items != null
          ? UnmodifiableListView<T>(items.map((e) => e.clone() as T))
          : this.items,
      query: query ?? this.query,
      selectedId: identical(selectedId, _sentinel)
          ? this.selectedId
          : selectedId as String?,
      totalCount: identical(totalCount, _sentinel)
          ? this.totalCount
          : totalCount as int?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error,
      stackTrace: identical(stackTrace, _sentinel)
          ? this.stackTrace
          : stackTrace as StackTrace?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NsgListState<T> &&
        listEquals(other.items, items) &&
        other.query == query &&
        other.selectedId == selectedId &&
        other.totalCount == totalCount &&
        other.hasMore == hasMore &&
        other.isLoading == isLoading &&
        other.isRefreshing == isRefreshing &&
        other.isLoadingMore == isLoadingMore &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    query,
    selectedId,
    totalCount,
    hasMore,
    isLoading,
    isRefreshing,
    isLoadingMore,
    error,
    stackTrace,
  );
}
