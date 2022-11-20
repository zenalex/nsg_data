import 'package:hive/hive.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:path_provider/path_provider.dart';

class NsgLocalDb {
  late BoxCollection collection;

  NsgLocalDb._();

  static NsgLocalDb instance = NsgLocalDb._();

  Map<String, CollectionBox<Map>> tables = {};

  Future init(String databaseName) async {
    String localPath = (await getApplicationDocumentsDirectory()).path + '/';
    print('local db path is $localPath');
    collection = await BoxCollection.open(
      '/'+ databaseName, // Name of database
      NsgDataClient.client
          .getAllRegisteredTypes()
          .toSet(), // Names of your boxes
      path:
          localPath, // Path where to store your boxes (Only used in Flutter / Dart IO)
      //key: null, // Key to encrypt your boxes (Only used in Flutter / Dart IO)
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

  Future<List<NsgDataItem>> requestItems(
      NsgDataItem dataItem, NsgDataRequestParams params) async {
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

  void _getIdFromCompare(
      List<String> ids, NsgDataItem dataItem, NsgCompare cmp) {
    for (var param in cmp.paramList) {
      if (param.parameterValue is NsgCompare) {
        _getIdFromCompare(ids, dataItem, param.parameterValue);
      } else {
        if (param.parameterName == dataItem.primaryKeyField) {
          if (param.parameterValue is List) {
            ids.addAll(param.parameterValue);
          } else {
            ids.add(param.parameterValue);
          }
        }
      }
    }
  }

  Future postItems(List<NsgDataItem> itemsToPost) async {
    if (itemsToPost.isEmpty) {
      return;
    }
    var firstItem = itemsToPost.first;
    var box = await getTable(firstItem.typeName);
    var tableFields = <String>[];
    for (var name in firstItem.fieldList.fields.keys) {
      if (firstItem.fieldList.fields[name] is NsgDataReferenceListField) {
        tableFields.add(name);
      }
    }
    for (var item in itemsToPost) {
      if (item.id.isEmpty) {
        item.id = Guid.newGuid();
      }
      //var map = item.toJson(excludeFields: tableFields);
      Map<dynamic, dynamic>? oldObject;
      if (tableFields.isNotEmpty) {
        oldObject = await box.get(item.id.toString());
      }
      var map = <String, dynamic>{};
      for (var name in item.fieldList.fields.keys) {
        if (tableFields.contains(name)) {
          var ls = <String>[];
          for (var row in item[name] as List<NsgDataItem>) {
            row.ownerId = item.id;
            ls.add(row.id);
          }
          //Читаем старый объект, извлекаем из него идентификаторы строк таб частей
          //Сравниваем с новыми, удаляем неиспользуемые
          var oldRowsId = oldObject != null ? oldObject![name] : null;
          if (oldRowsId != null &&
              (oldRowsId is List<String>?) &&
              oldRowsId!.isNotEmpty) {
            for (var e in ls) {
              oldRowsId.remove(e);
            }
            if (oldRowsId.isNotEmpty) {
              var tableBox = await getTable(
                  (item.getField(name) as NsgDataReferenceListField)
                      .referentElementType
                      .toString());
              tableBox.deleteAll(oldRowsId);
            }
          }

          map[name] = ls;
        } else {
          var value = item.fieldList.fields[name];
          map[name] = value!.convertToJson(item[name]);
        }
        box.put(item.id, map);
        for (var name in tableFields) {
          var list = item[name] as List<NsgDataItem>;
          if (list.isNotEmpty) {
            postItems(list);
          }
        }
      }
    }
  }
}
