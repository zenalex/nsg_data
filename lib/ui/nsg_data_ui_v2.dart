import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/ui/nsg_loading_scroll_controller.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';
import 'package:nsg_data/v2/controller/view/nsg_view_controller.dart';

// Import for MatchItem - this might need to be adjusted based on actual import path
// import 'package:footballers_diary_app/model/match_item.dart';

/// UI-миксин для `NsgDataController`, который упрощает построение списков с:
/// - постраничной/поштучной загрузкой данных (ленивая загрузка);
/// - поддержкой группировки по полю (например, по дате);
/// - автоматической прокруткой до текущего элемента;
/// - единообразной сортировкой и статусами загрузки.
///
/// Использование:
/// 1) Наследуйте контроллер от `NsgDataController<X>` и добавьте `with NsgDataUI`.
/// 2) Укажите `grFieldName`, если нужно разделять список разделителями (датами и т.п.).
/// 3) Отдайте виджет списка через `getListWidget`.
mixin NsgDataUIV2<T extends NsgDataItem> on NsgViewQueryControllerV2<T> {
  /// Сколько элементов подгружать за один шаг для UI.
  int loadStepCount = 25;

  /// Имя поля, по которому выполняется группировка (используется в `DataGroup`).
  String? groupFieldName;

  /// Дополнительные параметры сортировки (в дополнение к сортировке контроллера).
  List<NsgSortingParam>? sortingParams;

  /// Направление сортировки для поля группировки.
  NsgSortingDirection? sortDirection;

  @override
  NsgDataRequestParams get requestParams {
    var filter = super.requestParams.clone();
    filter.count = loadStepCount;

    NsgSorting sort = NsgSorting();

    if (groupFieldName != null && groupFieldName!.isNotEmpty) {
      NsgSortingParam sortingParam = NsgSortingParam(parameterName: groupFieldName!, direction: sortDirection ?? NsgSortingDirection.ascending);
      sort.paramList.add(sortingParam);
    }

    if (sortingParams != null) {
      for (var sortParam in sortingParams!) {
        sort.paramList.add(sortParam);
      }
    }

    if (filter.sorting != null) {
      var sortStr = sort.toString();
      if (sortStr.isNotEmpty) {
        filter.sorting = "$sortStr,${filter.sorting}";
      }
    } else {
      filter.sorting = sort.toString();
    }

    return filter;
  }

  /// Подгружает следующую порцию элементов и уведомляет слушателей об обновлении.
  FutureOr<void> loadNext({NsgDataRequestParams? requestParams, Iterable<String>? loadReference}) async {
    if (snapshot.totalCount == null) {
      return Future.value();
    }
    if (items.length < (snapshot.totalCount ?? 1000)) {
      dataController.store.update(dataController.snapshot.copyWith(status: NsgControllerStatus.loading));
      var params = (requestParams ?? this.requestParams).clone();
      params.top = items.length;
      params.count = loadStepCount;
      var loadedItems = await load(requestParams: params, loadReference: loadReference ?? this.loadReference);
      dataController.store.update(
        dataController.snapshot.copyWith(items: [...items, ...loadedItems], totalCount: snapshot.totalCount, status: NsgControllerStatus.success),
      );
    }
  }

  /// Контроллер ленивой прокрутки. При достижении конца списка вызывает `loadNext`.
  late NsgLoadingScrollController scrollController = NsgLoadingScrollController(
    function: () async {
      await loadNext();
    },
  );

  @override
  FutureOr<void> refresh({bool Function(T item)? filter, Iterable<String>? loadReference}) {
    scrollController.lastOffset = 0;
    scrollController.startUpdate();

    return super.refresh(filter: filter, loadReference: loadReference);
  }

  /// Прокручивает список к текущему выбранному элементу контроллера `currentItem`.
  void scrollToItem(T item) {
    scrollController.scrollToIndex(scrollController.dataGroups.getIndexByItem(item));
  }

  /// Возвращает реактивный (`obx`) виджет списка с поддержкой группировки.
  ///
  /// - `itemBuilder` — билдер элемента списка.
  /// - `dividerBuilder` — опциональный билдер разделителя группы (например, заголовок с датой).
  Widget listWidget(
    BuildContext context, {
    Widget Function(BuildContext context, T item)? itemBuilder,
    Widget Function(BuildContext context, dynamic groupValue)? dividerBuilder,
    Widget? onEmptyList,
  }) {
    return observeStatus(
      builder: (context, snapshot) {
        if (snapshot.items.isEmpty) {
          if (onEmptyList != null) {
            return onEmptyList;
          }
          return const SizedBox.shrink();
        }

        scrollController.dataGroups = DataGroupList([
          DataGroup(data: snapshot.items.toList(), groupFieldName: groupFieldName ?? ''),
        ], needDivider: dividerBuilder != null);

        return ListView.builder(
          controller: scrollController,
          itemCount: scrollController.dataGroups.length,
          itemBuilder: (context, index) {
            final element = scrollController.dataGroups.getElemet(index);
            if (element.isDivider && dividerBuilder != null) {
              return dividerBuilder(context, element.value);
            } else {
              return itemBuilder?.call(context, element.value as T) ?? const SizedBox.shrink();
            }
          },
        );
      },
    );
  }
}
