import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/riverpod/core/repository/nsg_entity_repository.dart';
import 'package:nsg_data/riverpod/core/state/nsg_list_state.dart';
import 'package:nsg_data/riverpod/core/query/nsg_list_query.dart';

abstract class NsgListNotifier<T extends NsgDataItem>
    extends Notifier<NsgListState<T>> {
  ProviderListenable<NsgEntityRepository<T>> get repositoryProvider;

  NsgEntityRepository<T> get repository => ref.read(repositoryProvider);

  NsgListQuery get initialQuery => NsgListQuery();

  @override
  NsgListState<T> build() {
    return NsgListState<T>(query: initialQuery, hasMore: false);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null, stackTrace: null);
    try {
      final result = await repository.fetchList(state.query);
      state = state.copyWith(
        items: result.items,
        totalCount: result.totalCount,
        hasMore: _resolveHasMore(
          totalLoadedCount: result.items.length,
          fetchedCount: result.items.length,
          totalCount: result.totalCount,
          query: state.query,
        ),
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: null,
        stackTrace: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, error: null, stackTrace: null);
    try {
      final result = await repository.fetchList(state.query);
      state = state.copyWith(
        items: result.items,
        totalCount: result.totalCount,
        hasMore: _resolveHasMore(
          totalLoadedCount: result.items.length,
          fetchedCount: result.items.length,
          totalCount: result.totalCount,
          query: state.query,
        ),
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: null,
        stackTrace: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final count = state.query.requestParams.count;
    if (count <= 0) {
      state = state.copyWith(hasMore: false);
      return;
    }

    final nextParams = state.query.requestParams.clone()
      ..top = state.items.length
      ..count = count;

    state = state.copyWith(isLoadingMore: true, error: null, stackTrace: null);

    try {
      final nextQuery = state.query.copyWith(requestParams: nextParams);
      final result = await repository.fetchList(nextQuery);
      final merged = _mergeItems(state.items, result.items);
      state = state.copyWith(
        items: merged,
        totalCount: result.totalCount,
        hasMore: _resolveHasMore(
          totalLoadedCount: merged.length,
          fetchedCount: result.items.length,
          totalCount: result.totalCount,
          query: nextQuery,
        ),
        isLoadingMore: false,
        error: null,
        stackTrace: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoadingMore: false,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void setQuery(NsgListQuery query) {
    state = state.copyWith(
      query: query,
      selectedId: null,
      totalCount: null,
      hasMore: false,
      error: null,
      stackTrace: null,
    );
  }

  void select(String? id) {
    state = state.copyWith(selectedId: id);
  }

  void clearSelection() {
    state = state.copyWith(selectedId: null);
  }

  void clearError() {
    state = state.copyWith(error: null, stackTrace: null);
  }

  bool _resolveHasMore({
    required int totalLoadedCount,
    required int fetchedCount,
    required int? totalCount,
    required NsgListQuery query,
  }) {
    if (totalCount != null) {
      return totalLoadedCount < totalCount;
    }

    final count = query.requestParams.count;
    if (count <= 0) return false;
    return fetchedCount >= count;
  }

  List<T> _mergeItems(Iterable<T> current, Iterable<T> incoming) {
    final items = <T>[...current];
    for (final item in incoming) {
      final existingIndex = items.indexWhere(
        (element) => element.id == item.id,
      );
      if (existingIndex >= 0) {
        items[existingIndex] = item;
      } else {
        items.add(item);
      }
    }
    return items;
  }
}
