import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/new_path_route.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/ui/nsg_loading_scroll_controller.dart';

mixin NsgDataUI<T extends NsgDataItem> on NsgDataController<T> {
  int loadStepCountUi = 25;
  String? grFieldName;
  List<NsgSortingParam>? sortingParams;
  NsgSortingDirection? sortDirection;

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

    if (grFieldName != null && grFieldName!.isNotEmpty) {
      NsgSortingParam sortingParam = NsgSortingParam(parameterName: grFieldName!, direction: sortDirection ?? NsgSortingDirection.ascending);
      sort.paramList.add(sortingParam);
    }

    if (sortingParams != null) {
      for (var sortParam in sortingParams!) {
        sort.paramList.add(sortParam);
      }
    }

    if (filter.sorting != null) {
      filter.sorting = "${sort.toString()},${filter.sorting}";
    } else {
      filter.sorting = sort.toString();
    }

    return filter;
  }

  Future loadNext({NsgDataRequestParams? filter}) async {
    status = GetStatus.loading();
    sendNotify();
    if (items.length + 1 < (totalCount ?? 1000)) {
      items.addAll(await _loadItems(items.length, loadStepCountUi, filter: filter));
    }
    status = GetStatus.success(NsgBaseController.emptyData);
    sendNotify();
  }

  late NsgLoadingScrollController scrollController = NsgLoadingScrollController(
    function: () async {
      await loadNext();
    },
  );

  void scrollToCurrentItem() {
    scrollController.scrollToIndex(scrollController.dataGroups.getIndexByItem(currentItem));
  }

  // void scrollToCurrentItem2() {
  //   scrollController.scrollToItemWhenVisible(scrollController.dataGroups.getIndexByItem(currentItem));
  // }
}

class DataGroup {
  DataGroup({required this.data, required this.groupFieldName, this.dividerBuilder}) {
    for (var d in data) {
      _itemsKeys.addAll({d: GlobalKey()});
    }
  }

  final List<NsgDataItem> data;
  final String groupFieldName;
  final Widget Function(String grName, dynamic fieldValue)? dividerBuilder;

  final Map<NsgDataItem, GlobalKey> _itemsKeys = {};
  Map<NsgDataItem, GlobalKey> get itemsKeys => _itemsKeys;

  String get groupName {
    if (groupValue != null) {
      try {
        return groupValue.toString();
      } catch (ex) {
        return "error";
      }
    }
    return "";
  }

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

class DataGroupList {
  DataGroupList(this.groups, {this.needDivider = false}) {
    Map<DataGroup, ({int first, int last})> map = {};
    int firstIndex = 0;
    for (var gr in groups) {
      map.addAll({gr: (first: firstIndex, last: firstIndex + gr.data.length - (needDivider ? 0 : 1))});
      _length = firstIndex + gr.data.length - (needDivider ? 0 : 1);
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

  int get length => _length;

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
      return (value: group.key.groupValue, group: group.key, isDivider: true, key: _itemsKeys[group.key.groupValue]);
    }
    throw (RangeError("index $index out of range"));
  }

  int getIndexByItem(NsgDataItem item) {
    for (int i = 0; i < _length; i++) {
      if (getElemet(i).value == item) {
        return i;
      }
    }
    return -1;
  }
}
