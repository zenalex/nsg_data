import 'package:nsg_data/nsg_data_fieldlist.dart';
import 'package:nsg_data/nsg_data_itemList.dart';
import 'package:nsg_data/nsg_data_provider.dart';
import 'nsg_data_item.dart';
import 'nsg_data_paramList.dart';

class NsgDataClient {
  NsgDataClient._();

  static NsgDataClient client = NsgDataClient._();

  final Map<Type, NsgDataItem> _registeredItems = <Type, NsgDataItem>{};
  final Map<Type, NsgFieldList> _fieldList = <Type, NsgFieldList>{};
  final Map<Type, NsgParamList> _paramList = <Type, NsgParamList>{};
  final Map<Type, NsgItemList> _itemList = <Type, NsgItemList>{};

  void registerDataItem(NsgDataItem item, {NsgDataProvider remoteProvider}) {
    if (remoteProvider != null) item.remoteProvider = remoteProvider;
    assert(item.remoteProvider != null);
    _registeredItems[item.runtimeType] = item;
    _fieldList[item.runtimeType] = NsgFieldList();
    item.initialize();
    assert(item.primaryKeyField != null);
  }

  NsgFieldList getFieldList(NsgDataItem item) {
    assert(_registeredItems.containsKey(item.runtimeType));
    return _fieldList[item.runtimeType];
  }

  NsgDataItem getNewObject(Type type) {
    assert(_registeredItems.containsKey(type));
    return _registeredItems[type].getNewObject();
  }

  NsgParamList getParamList(NsgDataItem item) {
    if (!_paramList.containsKey(item.runtimeType)) {
      _paramList[item.runtimeType] = NsgParamList();
    }
    return _paramList[item.runtimeType];
  }

  void addItemsToCache({List<NsgDataItem> items, String tag = ''}) {
    if (items == null || items.isEmpty) return;
    var time = DateTime.now();
    var cache = _getItemsCacheByType(items[0].runtimeType);
    items.forEach((item) {
      cache.add(item: item, time: time, tag: tag);
    });
  }

  NsgItemList _getItemsCacheByType(Type type) {
    if (!_itemList.containsKey(type)) {
      _itemList[type] = NsgItemList();
    }
    return _itemList[type];
  }

  NsgDataItem getItemsFromCache(Type type, String id) {
    var cache = _getItemsCacheByType(type);
    var item = cache.getItem(id);
    return item == null ? null : item.dataItem;
  }
}
