import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:path_provider/path_provider.dart';

class NsgLocalDb {
  late BoxCollection collection;

  NsgLocalDb._();

  static NsgLocalDb instance = NsgLocalDb._();

  Map<String, CollectionBox<Map>> tables = {};

  static bool initialized = false;
  static int _currentIteration = 0;
  static String _currentDatabaseName = '';
  static bool _reinitInProgress = false;
  static DateTime? _lastReinitTime;
  static const Duration _reinitCooldown = Duration(milliseconds: 500);
  final Set<String> _additionalBoxNames = {};

  Future init(String databaseName, {Set<String> extraBoxNames = const {}}) async {
    _currentDatabaseName = databaseName;
    // Merge additional box names (e.g., app-specific local boxes)
    if (extraBoxNames.isNotEmpty) {
      final missing = extraBoxNames.difference(_additionalBoxNames);
      if (missing.isNotEmpty) {
        _additionalBoxNames.addAll(missing);
        // If already initialized without these boxes, reinitialize to include them
        if (initialized) {
          await _reinitializeDatabase();
          return;
        }
      } else {
        if (initialized) {
          return;
        }
      }
    } else if (initialized) {
      return;
    }
    //Для возможности запуска нескольких экземпляров программы одновременно, пока сделано решение, что для каждого экземпляра будет своя БД
    //Решение спорное, но лучше так, чем никак
    var iteration = 0;
    while (true) {
      try {
        String localPath = './';
        if (!kIsWeb) {
          localPath = '${(await getApplicationDocumentsDirectory()).path}/';
        }

        final boxNames = {...NsgDataClient.client.getAllRegisteredServerNames(), ..._additionalBoxNames};
        collection = await BoxCollection.open(
          '/$databaseName${iteration++ == 0 ? '' : iteration.toString()}', // Name of database
          boxNames, // Names of your boxes
          path: localPath, // Path where to store your boxes (Only used in Flutter / Dart IO)
          //key: null, // Key to encrypt your boxes (Only used in Flutter / Dart IO)
        );

        _currentIteration = iteration - 1; // Сохраняем успешную итерацию

        // Note: Hive CE automatically handles compaction, but it can fail during
        // concurrent access or file locking issues. We handle these errors gracefully
        // in the individual database operation methods below.
      } catch (ex) {
        if (kDebugMode) {
          print(ex);
        }
        if (iteration < 10) {
          continue;
        }
        // Если все итерации провалились, инициализируем без локальной БД
        initialized = true;
        return;
      }
      break;
    }
    initialized = true;
  }

  /// Переинициализация базы данных с новой итерацией при ошибках
  Future<bool> _reinitializeDatabase() async {
    if (!initialized || _currentDatabaseName.isEmpty) {
      return false;
    }

    // Cooldown and concurrency guard
    if (_reinitInProgress) {
      if (kDebugMode) {
        print('Reinitialization is already in progress, skipping');
      }
      return false;
    }
    final now = DateTime.now();
    if (_lastReinitTime != null && now.difference(_lastReinitTime!) < _reinitCooldown) {
      if (kDebugMode) {
        print('Reinitialization cooldown active, skipping');
      }
      return false;
    }
    _reinitInProgress = true;

    _currentIteration++;
    if (_currentIteration >= 10) {
      if (kDebugMode) {
        print('Maximum database iterations reached, disabling local storage');
      }
      initialized = false; // Отключаем локальную БД
      tables.clear();
      _reinitInProgress = false;
      _lastReinitTime = DateTime.now();
      return false;
    }

    try {
      String localPath = './';
      if (!kIsWeb) {
        localPath = '${(await getApplicationDocumentsDirectory()).path}/';
      }

      final boxNames = {...NsgDataClient.client.getAllRegisteredServerNames(), ..._additionalBoxNames};
      var newCollection = await BoxCollection.open(
        '/$_currentDatabaseName${_currentIteration == 0 ? '' : _currentIteration.toString()}',
        boxNames,
        path: localPath,
      );

      // Закрываем старую коллекцию
      collection.close();

      collection = newCollection;
      tables.clear(); // Очищаем кэш боксов

      if (kDebugMode) {
        print('Successfully reinitialized database with iteration $_currentIteration');
      }
      return true;
    } catch (ex) {
      if (kDebugMode) {
        print('Failed to reinitialize database with iteration $_currentIteration: $ex');
      }
      return false;
    } finally {
      _reinitInProgress = false;
      _lastReinitTime = DateTime.now();
    }
  }

  Future<CollectionBox<Map>> getTable(String tableName) async {
    var box = tables[tableName];
    if (box != null) {
      return box;
    }
    try {
      box = await collection.openBox<Map>(
        tableName,
        // Hive CE requires explicit converters for non-primitive types (like Map) on web.
        fromJson: (dynamic json) => (json as Map).cast<dynamic, dynamic>(),
      );
      tables[tableName] = box;
      return box;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening box $tableName: $e');
      }
      // If box opening fails due to compaction issues, try to reinitialize database
      if (e.toString().contains('rename') || e.toString().contains('compact')) {
        if (kDebugMode) {
          print('Compaction error opening box $tableName, trying to reinitialize database');
        }
        var reinitialized = await _reinitializeDatabase();
        if (reinitialized) {
          // Try to get the table again with the new database
          return getTable(tableName);
        } else {
          // Database reinitialization failed
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<List<NsgDataItem>> requestItems(NsgDataItem dataItem, NsgDataRequestParams params, {String tag = ''}) async {
    try {
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
          if (params.compare.isValid(item)) {
            items.add(item);
          }
        }
      } else {
        var valueMap = await box.getAll(idList);
        for (var mapValue in valueMap) {
          if (mapValue == null) continue;
          var item = NsgDataClient.client.getNewObject(dataItem.runtimeType);
          item.fromJson(mapValue.cast());
          item.storageType = NsgDataStorageType.local;
          if (params.compare.isValid(item)) {
            items.add(item);
          }
        }
      }
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);
      return items;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting items from database: $e');
      }
      // If it's a compaction-related error, try to reinitialize database
      if (e.toString().contains('compact') || e.toString().contains('rename')) {
        if (kDebugMode) {
          print('Compaction error during requestItems, trying to reinitialize database');
        }
        var reinitialized = await _reinitializeDatabase();
        if (reinitialized) {
          // Try the operation again with the new database
          return requestItems(dataItem, params, tag: tag);
        } else {
          // Database reinitialization failed, return empty list
          return [];
        }
      }
      rethrow;
    }
  }

  void _getIdFromCompare(List<String> ids, NsgDataItem dataItem, NsgCompare cmp) {
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

    try {
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
        item.state = NsgDataItemState.fill;
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
            var oldRowsId = oldObject != null ? oldObject[name] : null;
            if (oldRowsId != null && (oldRowsId is List<String>?) && oldRowsId!.isNotEmpty) {
              for (var e in ls) {
                oldRowsId.remove(e);
              }
              if (oldRowsId.isNotEmpty) {
                var tableBox = await getTable((item.getField(name) as NsgDataReferenceListField).referentElementType.toString());
                tableBox.deleteAll(oldRowsId);
              }
            }

            map[name] = ls;
          } else {
            var value = item.fieldList.fields[name];
            map[name] = value!.convertToJson(item[name]);
          }
        }
        await box.put(item.id, map);

        for (var name in tableFields) {
          var list = item[name] as List<NsgDataItem>;
          if (list.isNotEmpty) {
            postItems(list);
          }
        }
      }
      NsgDataClient.client.addItemsToCache(items: itemsToPost);
    } catch (e) {
      if (kDebugMode) {
        print('Error posting items to database: $e');
      }
      // If it's a compaction-related error, try to reinitialize database
      if (e.toString().contains('compact') || e.toString().contains('rename')) {
        if (kDebugMode) {
          print('Compaction error during postItems, trying to reinitialize database');
        }
        var reinitialized = await _reinitializeDatabase();
        if (reinitialized) {
          // Try the operation again with the new database
          await postItems(itemsToPost);
          return;
        } else {
          // Database reinitialization failed, continue without local storage
          return;
        }
      }
      rethrow;
    }
  }

  Future deleteItems(List<NsgDataItem> itemsToDelete) async {
    if (itemsToDelete.isEmpty) {
      return;
    }
    var firstItem = itemsToDelete.first;
    var box = await getTable(firstItem.typeName);
    var ids = <String>[];
    for (var item in itemsToDelete) {
      if (item.id.isEmpty) {
        continue;
      }
      ids.add(item.id);
    }
    try {
      await box.deleteAll(ids);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting items from database: $e');
      }
      // If it's a compaction-related error, try to reinitialize database
      if (e.toString().contains('compact') || e.toString().contains('rename')) {
        if (kDebugMode) {
          print('Compaction error during deleteItems, trying to reinitialize database');
        }
        var reinitialized = await _reinitializeDatabase();
        if (reinitialized) {
          // Try the operation again with the new database
          await deleteItems(itemsToDelete);
          return;
        } else {
          // Database reinitialization failed, continue without local storage
          return;
        }
      }
      rethrow;
    }
  }
}
