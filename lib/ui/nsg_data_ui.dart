import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/new_path_route.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/ui/nsg_loading_scroll_controller.dart';

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
mixin NsgDataUI<T extends NsgDataItem> on NsgDataController<T> {
  /// Сколько элементов подгружать за один шаг для UI.
  int loadStepCountUi = 25;

  /// Имя поля, по которому выполняется группировка (используется в `DataGroup`).
  String? groupFieldName;

  /// Дополнительные параметры сортировки (в дополнение к сортировке контроллера).
  List<NsgSortingParam>? sortingParams;

  /// Направление сортировки для поля группировки.
  NsgSortingDirection? sortDirection;

  /// Загружает часть элементов из источника данных с учётом фильтра и ссылок.
  /// `top` — смещение; `count` — сколько элементов загрузить.
  Future<List<T>> _loadItems(int top, int count, {NsgDataRequestParams? filter}) async {
    if (controllerMode.storageType == NsgDataStorageType.local) {
      return [];
    }
    var matches = NsgDataRequest<T>(dataItemType: T, storageType: controllerMode.storageType);
    filter ??= getRequestFilter;
    filter.top = top;
    filter.count = count;
    // printWarning("top - $top");
    // printWarning("count - $count");
    // printWarning("last - ${top + count}");
    List<T> ans = await matches.requestItems(filter: filter, loadReference: referenceList);
    return ans;
  }

  @override
  NsgDataRequestParams get getRequestFilter {
    var filter = super.getRequestFilter;
    filter.count = loadStepCountUi;

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
        filter.sorting = "${sortStr},${filter.sorting}";
      }
    } else {
      filter.sorting = sort.toString();
    }

    return filter;
  }

  /// Подгружает следующую порцию элементов и уведомляет слушателей об обновлении.
  Future loadNext({NsgDataRequestParams? filter}) async {
    status = GetStatus.loading();
    sendNotify();
    if (items.length + 1 < (totalCount ?? 1000)) {
      items.addAll(await _loadItems(items.length, loadStepCountUi, filter: filter));
    }
    status = GetStatus.success(NsgBaseController.emptyData);
    sendNotify();
  }

  /// Контроллер ленивой прокрутки. При достижении конца списка вызывает `loadNext`.
  late NsgLoadingScrollController scrollController = NsgLoadingScrollController(
    function: () async {
      await loadNext();
    },
  );

  /// Прокручивает список к текущему выбранному элементу контроллера `currentItem`.
  void scrollToCurrentItem() {
    scrollController.scrollToIndex(scrollController.dataGroups.getIndexByItem(currentItem));
  }

  // void scrollToCurrentItem2() {
  //   scrollController.scrollToItemWhenVisible(scrollController.dataGroups.getIndexByItem(currentItem));
  // }

  /// Возвращает реактивный (`obx`) виджет списка с поддержкой группировки.
  ///
  /// - `itemBuilder` — билдер элемента списка.
  /// - `dividerBuilder` — опциональный билдер разделителя группы (например, заголовок с датой).
  Widget getListWidgetInData(Widget? Function(T item) itemBuilder, {Widget Function(dynamic groupValue)? dividerBuilder, Widget? onEmptyList}) {
    return obx((state) {
      if (items.isEmpty) {
        if (onEmptyList != null) {
          return onEmptyList;
        }
        return const SizedBox.shrink();
      }

      scrollController.dataGroups = DataGroupList([DataGroup(data: items, groupFieldName: groupFieldName ?? '')], needDivider: dividerBuilder != null);

      return ListView.builder(
        controller: scrollController,
        itemCount: scrollController.dataGroups.length,
        itemBuilder: (context, index) {
          final element = scrollController.dataGroups.getElemet(index);
          if (element.isDivider && dividerBuilder != null) {
            return dividerBuilder(element.value);
          } else if (!element.isDivider) {
            return itemBuilder(element.value as T);
          }
          return const SizedBox.shrink();
        },
      );
    });
  }
}

/// Представляет одну группу данных в списке (например, все элементы одного дня).
/// Хранит сами элементы, имя поля группировки и ключи для точной прокрутки к элементам.
class DataGroup {
  DataGroup({required this.data, required this.groupFieldName, this.dividerBuilder, this.partOfDate}) {
    for (var d in data) {
      _itemsKeys.addAll({d: GlobalKey()});
    }
  }

  /// Элементы группы.
  final List<NsgDataItem> data;

  ///Часть даты сортировки
  final PartOfDate? partOfDate;

  /// Имя поля в модели, по которому вычисляется `groupValue`.
  final String groupFieldName;

  /// Кастомный билдер разделителя группы (опционально).
  final Widget Function(String grName, dynamic fieldValue)? dividerBuilder;

  final Map<NsgDataItem, GlobalKey> _itemsKeys = {};
  Map<NsgDataItem, GlobalKey> get itemsKeys => _itemsKeys;

  /// Человекочитаемое имя группы на основе `groupValue`.
  String get groupName {
    if (groupValue != null) {
      try {
        if (groupValue is DateTime && partOfDate != null) {
          return NsgDateFormat.dateFormat(groupValue, format: partOfDate!.formatTime, locale: Localizations.localeOf(Get.context!).languageCode);
        }
        return groupValue.toString();
      } catch (ex) {
        return "error";
      }
    }
    return "";
  }

  /// Значение поля группировки для первой записи в группе.
  /// Поддерживаются ссылочные, перечислимые, булевые, строковые, числовые и датовые поля.
  dynamic get groupValue {
    if (data.isNotEmpty) {
      try {
        if (data.first.getField(groupFieldName) is NsgDataReferenceField) {
          return data.first.getReferent(groupFieldName);
        } else if (data.first.getField(groupFieldName) is NsgDataEnumReferenceField) {
          return data.first.getReferent(groupFieldName);
        } else if (data.first.getField(groupFieldName) is NsgDataBoolField) {
          return data.first.getFieldValue(groupFieldName);
        } else if (data.first.getField(groupFieldName) is NsgDataStringField ||
            data.first.getField(groupFieldName) is NsgDataIntField ||
            data.first.getField(groupFieldName) is NsgDataDoubleField) {
          return data.first.getFieldValue(groupFieldName);
        } else if (data.first.getField(groupFieldName) is NsgDataDateField) {
          return data.first.getFieldValue(groupFieldName);
        } else {
          throw Exception("Не указан тип поля ввода, тип данных неизвестен");
        }
      } catch (ex) {
        return null;
      }
    }
    return null;
  }
}

/// Коллекция групп `DataGroup` с быстрым доступом по индексу и поддержкой разделителей.
///
/// Отвечает за сопоставление линейного индекса `ListView` к конкретному элементу
/// или разделителю группы, корректно учитывая наличие/отсутствие divider-строк.
class DataGroupList {
  DataGroupList(this.groups, {this.needDivider = false}) {
    Map<DataGroup, ({int first, int last})> map = {};
    int firstIndex = 0;
    for (var gr in groups) {
      map.addAll({gr: (first: firstIndex, last: firstIndex + gr.data.length - 1 + (needDivider ? 1 : 0))});
      // _length должен содержать ОБЩЕЕ количество элементов (включая divider),
      // а не индекс последнего элемента. Поэтому прибавляем 1, когда есть divider.
      _length = firstIndex + gr.data.length + (needDivider ? 1 : 0);
      firstIndex += gr.data.length + (needDivider ? 1 : 0);
      _itemsKeys.addEntries(gr.itemsKeys.entries);
    }
    _sizes = map;
  }

  final Map<NsgDataItem, GlobalKey> _itemsKeys = {};

  Map<int, GlobalKey> get itemsKeys {
    Map<int, GlobalKey> map = {};
    _itemsKeys.forEach((k, v) => map.addAll({getIndexByItem(k): v}));
    return map;
  }

  bool needDivider;
  List<DataGroup> groups;

  Map<DataGroup, ({int first, int last})> _sizes = {};
  int _length = 0;

  /// Общее количество строк списка (элементы + разделители).
  int get length => _length;

  /// Возвращает описание элемента по индексу.
  /// Если это разделитель — `isDivider == true` и `value` содержит значение группы (например, дату).
  /// Если это обычный элемент — `isDivider == false` и `value` содержит сам `NsgDataItem`.
  ({dynamic value, DataGroup group, bool isDivider, GlobalKey? key}) getElemet(int index) {
    var group = _sizes.entries.firstWhereOrNull((i) => i.value.first <= index && index <= i.value.last);
    if (group != null) {
      if (index - group.value.first > 0 || !needDivider) {
        return (
          value: group.key.data[index - group.value.first - (needDivider ? 1 : 0)],
          group: group.key,
          isDivider: false,
          key: _itemsKeys[group.key.data[index - group.value.first - (needDivider ? 1 : 0)]],
        );
      }
      return (value: group.key.groupValue, group: group.key, isDivider: true, key: _itemsKeys[group.key.groupValue] ?? GlobalKey());
    }
    throw (RangeError("index $index out of range"));
  }

  /// Возвращает индекс строки, соответствующей заданному элементу `item`.
  int getIndexByItem(NsgDataItem item) {
    for (int i = 0; i < _length; i++) {
      if (getElemet(i).value == item) {
        return i;
      }
    }
    return -1;
  }
}

enum PartOfDate {
  second,
  minute,
  hour,
  day,
  month,
  year;

  const PartOfDate();

  String get formatTime {
    switch (this) {
      case second:
        return "HH:mm:ss dd.MM.yyyy";
      case minute:
        return "HH:mm dd.MM.yyyy";
      case hour:
        return "HH dd.MM.yyyy";
      case day:
        return "dd.MM.yyyy";
      case month:
        return "MM.yyyy";
      case year:
        return "yyyy";
    }
  }
}
