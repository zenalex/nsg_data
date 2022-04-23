import 'package:nsg_data/nsg_data_itemList.dart';
import 'nsg_data.dart';
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

  NsgFieldList getFieldList(Type itemType) {
    if (_registeredItems.containsKey(itemType.toString()))
      return _fieldList[itemType.toString()]!;
    throw ArgumentError('getFieldList: $itemType not found');
  }

  bool isRegistered(Type type) {
    return (_registeredItems.containsKey(type.toString()));
  }

  NsgDataItem getNewObject(Type type) {
    assert(_registeredItems.containsKey(type.toString()));
    return _registeredItems[type.toString()]!.getNewObject();
  }

  NsgParamList getParamList(Type itemType) {
    if (!_paramList.containsKey(itemType.toString())) {
      _paramList[itemType.toString()] = NsgParamList();
    }
    return _paramList[itemType.toString()]!;
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

  NsgDataItem? getItemsFromCache(Type type, String id,
      {bool allowNull = false}) {
    var cache = _getItemsCacheByType(type)!;
    var item = cache.getItem(id);
    return item == null
        ? (allowNull ? null : NsgDataClient.client.getNewObject(type))
        : item.dataItem;
  }

  NsgDataBaseReferenceField? getReferentFieldByFullPath(
      Type dataType, String fullPath) {
    var splitedPath = fullPath.split('.');
    var type = dataType;
    var fieldFound = false;
    NsgDataBaseReferenceField? foundField;
    for (var i = 0; i < splitedPath.length; i++) {
      fieldFound = false;
      var fieldList = NsgDataClient.client.getFieldList(type);
      if (fieldList.fields.containsKey(splitedPath[i])) {
        var field = fieldList.fields[splitedPath[i]];
        if (field is NsgDataReferenceField) {
          type = field.referentType;
          foundField = field;
          fieldFound = true;
        } else if (field is NsgDataReferenceListField) {
          type = field.referentElementType;
          fieldFound = true;
          foundField = field;
        }
      }
    }
    if (fieldFound) {
      return foundField;
    } else {
      return null;
    }
  }
}
