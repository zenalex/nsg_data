import 'package:nsg_data/nsg_data_fieldlist.dart';
import 'package:nsg_data/nsg_data_itemList.dart';
import 'package:nsg_data/nsg_data_provider.dart';
import 'nsg_data_item.dart';
import 'nsg_data_paramList.dart';

class NsgDataClient {
  NsgDataClient._();

  static NsgDataClient client = NsgDataClient._();

  final _registeredItems = <String, NsgDataItem>{};
  final _fieldList = <String, NsgFieldList>{};
  final _paramList = <String, NsgParamList>{};
  final _itemList = <String, NsgItemList>{};

  void registerDataItem(NsgDataItem item, {NsgDataProvider? remoteProvider}) {
    if (remoteProvider != null) item.remoteProvider = remoteProvider;
    _registeredItems[item.runtimeType.toString()] = item;
    _fieldList[item.runtimeType.toString()] = NsgFieldList();
    item.initialize();
  }

  NsgFieldList getFieldList(NsgDataItem item) {
    if (_registeredItems.containsKey(item.runtimeType.toString()))
      return _fieldList[item.runtimeType.toString()]!;
    throw ArgumentError('getFieldList: ${item.runtimeType} not found');
  }

  bool isRegistered(Type type) {
    return (_registeredItems.containsKey(type.toString()));
  }

  NsgDataItem getNewObject(Type type) {
    assert(_registeredItems.containsKey(type.toString()));
    return _registeredItems[type.toString()]!.getNewObject();
  }

  NsgParamList getParamList(NsgDataItem item) {
    if (!_paramList.containsKey(item.runtimeType.toString())) {
      _paramList[item.runtimeType.toString()] = NsgParamList();
    }
    return _paramList[item.runtimeType.toString()]!;
  }

  void addItemsToCache({List<NsgDataItem?>? items, String? tag = ''}) {
    if (items == null || items.isEmpty) return;
    var time = DateTime.now();
    var cache = _getItemsCacheByType(items[0].runtimeType);
    items.forEach((item) {
      cache!.add(item: item!, time: time, tag: tag);
    });
  }

  NsgItemList? _getItemsCacheByType(Type type) {
    if (!_itemList.containsKey(type.toString())) {
      _itemList[type.toString()] = NsgItemList();
    }
    return _itemList[type.toString()];
  }

  NsgDataItem? getItemsFromCache(Type type, String id) {
    var cache = _getItemsCacheByType(type)!;
    var item = cache.getItem(id);
    return item == null ? null : item.dataItem;
  }
}
