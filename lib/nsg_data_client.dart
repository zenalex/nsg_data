import 'package:nsg_data/nsg_data_itemList.dart';
import 'nsg_data.dart';
import 'nsg_data_paramList.dart';

class NsgDataClient {
  NsgDataClient._();

  static NsgDataClient client = NsgDataClient._();

  final _registeredItems = <String, NsgDataItem>{};
  final _registeredServerNames = <String, String>{};
  final _fieldList = <String, NsgFieldList>{};
  final _paramList = <String, NsgParamList>{};
  final _itemList = <String, NsgItemList>{};

  ///Количество зарегистрированных типов данных в провайдере
  int get registeredDataItemsCount => _registeredItems.keys.length;

  void registerDataItem(NsgDataItem item, {NsgDataProvider? remoteProvider, NsgLocalDb? localDb}) {
    if (remoteProvider != null) item.remoteProvider = remoteProvider;
    _registeredItems[item.runtimeType.toString()] = item;
    _registeredServerNames[item.typeName] = item.runtimeType.toString();
    _fieldList[item.runtimeType.toString()] = NsgFieldList();
    item.initialize();
  }

  List<String> getAllRegisteredTypes() {
    return _registeredItems.keys.toList();
  }

  NsgFieldList getFieldList(Type itemType) {
    if (_registeredItems.containsKey(itemType.toString())) {
      return _fieldList[itemType.toString()]!;
    }
    throw ArgumentError('getFieldList: $itemType not found');
  }

  bool isRegistered(Type type) {
    return (_registeredItems.containsKey(type.toString()));
  }

  bool isRegisteredByName(String typeName) {
    return (_registeredItems.containsKey(typeName));
  }

  bool isRegisteredByServerName(String typeName) {
    return (_registeredServerNames.containsKey(typeName) && _registeredItems.containsKey(_registeredServerNames[typeName]));
  }

  NsgDataItem getNewObject(Type type) {
    return getNewObjectByTypeName(type.toString());
  }

  NsgDataItem getNewObjectByTypeName(String typeName) {
    assert(_registeredItems.containsKey(typeName));
    return _registeredItems[typeName]!.getNewObject();
  }

  Type getTypeByName(String typeName) {
    assert(_registeredItems.containsKey(typeName), 'typeName = $typeName');
    return _registeredItems[typeName]!.runtimeType;
  }

  Type getTypeByServerName(String typeName) {
    assert(_registeredServerNames.containsKey(typeName), 'typeName = $typeName');
    return _registeredItems[_registeredServerNames[typeName]]!.runtimeType;
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
    for (var item in items) {
      cache!.add(item: item!, time: time, tag: tag);
    }
  }

  NsgItemList? _getItemsCacheByType(Type type) {
    if (!_itemList.containsKey(type.toString())) {
      _itemList[type.toString()] = NsgItemList();
    }
    return _itemList[type.toString()];
  }

  NsgDataItem? getItemsFromCache(Type type, String id, {bool allowNull = false}) {
    var cache = _getItemsCacheByType(type)!;
    var item = cache.getItem(id);
    return item == null ? (allowNull ? null : NsgDataClient.client.getNewObject(type)) : item.dataItem;
  }

  NsgDataBaseReferenceField? getReferentFieldByFullPath(Type dataType, String fullPath) {
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
