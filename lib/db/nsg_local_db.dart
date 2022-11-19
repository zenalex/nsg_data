import 'package:hive/hive.dart';
import 'package:nsg_data/nsg_data.dart';

class NsgLocalDb {
  late BoxCollection collection;

  NsgLocalDb._();

  static NsgLocalDb instance = NsgLocalDb._();

  Map<String, CollectionBox<Map>> tables = {};

  Future init(String databaseName) async {
    collection = await BoxCollection.open(
      databaseName, // Name of database
      NsgDataClient.client.getAllRegisteredTypes().toSet(), // Names of your boxes
      path: './', // Path where to store your boxes (Only used in Flutter / Dart IO)
      key: null, // Key to encrypt your boxes (Only used in Flutter / Dart IO)
    );
  }

  Future<CollectionBox<Map>> getTable(String tableName) async {
    var box = tables[tableName];
    if (box != null) {
      return box;
    }
    box = await collection.openBox<Map>(tableName);
    tables[tableName] = box;
    return box;
  }

  Future<List<NsgDataItem>> requestItems(NsgDataItem dataItem, NsgDataRequestParams params) async {
    var box = await getTable(dataItem.typeName);
    var items = <NsgDataItem>[];
    //определяем нет ли в запросе ограничения по id
    var idList = <String>[];
    _getIdFromCompare(idList, dataItem, params.compare);

    if (idList.isEmpty) {
      var valueMap = await box.getAllValues();
      for (var mapKey in valueMap.keys) {
        var item = NsgDataClient.client.getNewObject(dataItem.runtimeType);
        item.fromJson(valueMap[mapKey]!.cast());
        item.storageType = NsgDataStorageType.local;
        items.add(item);
      }
    } else {
      var valueMap = await box.getAll(idList);
      for (var mapValue in valueMap) {
        if (mapValue == null) continue;
        var item = NsgDataClient.client.getNewObject(dataItem.runtimeType);
        item.fromJson(mapValue.cast());
        item.storageType = NsgDataStorageType.local;
        items.add(item);
      }
    }

    return items;
  }

  void _getIdFromCompare(List<String> ids, NsgDataItem dataItem, NsgCompare cmp) {
    for (var param in cmp.paramList) {
      if (param.parameterValue is NsgCompare) {
        _getIdFromCompare(ids, dataItem, param.parameterValue);
      } else {
        if (param.parameterName == dataItem.primaryKeyField) {
          ids.add(param.parameterValue);
        }
      }
    }
  }

  Future postItems(List<NsgDataItem> itemsToPost) async {
    if (itemsToPost.isEmpty) {
      return;
    }
    var box = await getTable(itemsToPost.first.typeName);

    for (var item in itemsToPost) {
      if (item.id.isEmpty) {
        item.id = Guid.newGuid();
      }
      var map = item.toJson();
      box.put(item.id, map);
    }
  }
}
