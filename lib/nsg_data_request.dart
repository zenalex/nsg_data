import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:retry/retry.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items = <T>[];

  ///Сколько всего элементов, удовлетворяющих условиям поиска, есть на сервере
  int? totalCount;
  Type dataItemType;
  FutureOr<bool> Function(Exception)? retryIf;
  NsgDataStorageType storageType;

  NsgDataRequest({this.dataItemType = NsgDataItem, this.storageType = NsgDataStorageType.server}) {
    if (dataItemType == NsgDataItem) dataItemType = T;
  }

  List<NsgDataItem> _fromJsonList(List<dynamic> maps) {
    var items = <T>[];
    for (var m in maps) {
      var elem = NsgDataClient.client.getNewObject(dataItemType);
      elem.fromJson(m as Map<String, dynamic>);
      // elem.state = NsgDataItemState.fill;
      items.add(elem as T);
    }
    return items;
  }

  ///Запрос одного объекта. Для запроса списка объектов используйте requestItems
  ///Выполняет запрос по стандартному методу, заданному в бъекте
  ///Можно перекрыть для изменения логики запроса
  ///filter = доп. фильтр, особенное внимание следует обратить на его сво-во compare
  ///autoAuthorize - переход на авторизацию, если будет получен отказ в доступе
  ///tag - доп признак для кэширования
  ///loadReference - список полей для дочитывания, можно передавать через точку, null - будут дочитаны все поля
  ///                ссылочного типа первого уровн, пустой массив - не будет дочитано ничего
  ///                Обратите внимание, по умолчанию дочитываются все поля, что может негативно сказаться на производительности
  ///function - url вызываемого метода, если не задан, будет взят url данного объекта по умолчанию
  ///method - метод запроса. Рекомендуем всегда использовать POST из-за отсутствия ограничений на передаваемые параметры
  ///postData - передаваемые данные. Не рекомендуется использовать напрямую
  ///autoRepeate - повторять ли запрос в случае ошибки связи
  ///autoRepeateCount - максимальное количество повторов
  ///retryIf - функция, вызываемая перед каждым повторным вызовом. Если вернет false, повторы будут остановлены
  ///onRetry - функция, вызываемая при каждом повторе запроса
  Future<List<T>> requestItems({
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    List<String>? loadReference,
    String function = '',
    String method = 'GET',
    dynamic postData,
    bool autoRepeate = false,
    int autoRepeateCount = 1000,
    FutureOr<bool> Function(Exception)? userRetryIf,
    FutureOr<void> Function(Exception)? userOnRetry,
    NsgCancelToken? cancelToken,
  }) async {
    if (storageType == NsgDataStorageType.server) {
      retryIf = retryIf;
      if (autoRepeate) {
        final r = RetryOptions(maxAttempts: autoRepeateCount);
        return await r.retry(
            () => _requestItems(
                filter: filter,
                autoAuthorize: autoAuthorize,
                tag: tag,
                loadReference: loadReference,
                function: function,
                method: method,
                postData: postData,
                externalCancelToken: cancelToken),
            retryIf: _retryIfInternal,
            onRetry: userOnRetry);
        // onRetry: (error) => _updateStatusError(error.toString()));
      } else {
        return await _requestItems(
            filter: filter,
            autoAuthorize: autoAuthorize,
            tag: tag,
            loadReference: loadReference,
            function: function,
            method: method,
            postData: postData,
            externalCancelToken: cancelToken);
      }
    } else {
      return await _requestItemsFromDb(filter: filter, tag: tag, loadReference: loadReference);
    }
  }

  ///Токен текущего запроса. При повторном вызове запроса, предыдущий запрос будет отменен автоматически
  ///В будущем, планируется добавить механизм, уведомляющий сервер об отмене запроса с целью прекращения подготовки ненужных данных
  NsgCancelToken? cancelToken;
  Future<List<T>> _requestItems({
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    List<String>? loadReference,
    String function = '',
    String method = 'GET',
    Map<String, dynamic>? postData,
    NsgCancelToken? externalCancelToken,
  }) async {
    if (cancelToken != null && externalCancelToken != cancelToken && !cancelToken!.isCalceled) {
      cancelToken!.calcel();
    }
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);
    var filterMap = <String, dynamic>{};

    //Добавление в запрос имен полей, требующих дочитывания
    if (loadReference == null && dataItem.loadReferenceDefault != null) {
      loadReference = dataItem.loadReferenceDefault;
    }
    if (loadReference == null) {
      loadReference = [];
      loadReference = addAllReferences(dataItem.runtimeType);
    }
    filter ??= NsgDataRequestParams();
    filter.readNestedField = loadReference.join(',');

    method = 'POST';
    if (method == 'GET') {
      filterMap = filter.toJson();
    } else {
      postData ??= {};
      postData.addAll(filter.toJson());
    }

    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiRequestItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }
    var url = function;
    var response = await dataItem.remoteProvider.baseRequestList(
        function: url,
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: url,
        method: method,
        params: filterMap,
        postData: postData,
        cancelToken: cancelToken);
    items = <T>[];
    try {
      if (response == '' || response == null) {
      } else {
        if (response is Map) {
          items = (await loadDataAndReferences(response, loadReference, tag, filter: filter)).cast();
        } else {
          if (response is! List) {
            response = <dynamic>[response];
          }
          items = _fromJsonList(response).cast();
          NsgDataClient.client.addItemsToCache(items: items, tag: tag);

          //Check referent field list
          await loadAllReferents(items, loadReference, tag: tag);
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return items;
  }

  Future<List<T>> _requestItemsFromDb({NsgDataRequestParams? filter, String tag = '', List<String>? loadReference}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);

    //Добавление в запрос имен полей, требующих дочитывания
    if (loadReference == null && dataItem.loadReferenceDefault != null) {
      loadReference = dataItem.loadReferenceDefault;
    }
    if (loadReference == null) {
      loadReference = [];
      loadReference = addAllReferences(dataItem.runtimeType);
    }
    filter ??= NsgDataRequestParams();
    filter.readNestedField = loadReference.join(',');

    items = (await NsgLocalDb.instance.requestItems(dataItem, filter)).cast();

    try {
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);

      //Check referent field list
      await loadAllReferents(items, loadReference, tag: tag, readTableParts: true);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return items;
  }

  ///Загружает данные из response, представляющего из себя Map.
  ///основные объекты лежат в results, кэшируемые по названию полей основного объекта
  Future<List> loadDataAndReferences(Map response, List<String> loadReference, String tag, {NsgDataRequestParams? filter}) async {
    var maps = response as Map<String, dynamic>;
    //Новые основные элементы
    var newItems = <NsgDataItem>[];
    //Все новые элементы, включая дочитанные объекты для поиска строк табличных частей
    var allItems = <NsgDataItem>[];
    var useCache = (filter == null || filter.fieldsToRead == null || filter.fieldsToRead!.isEmpty);
    maps.forEach((name, data) {
      if (name == '_results_' || name == 'results') {
        newItems = _fromJsonList(data);
        allItems.addAll(newItems);
        if (newItems.isNotEmpty && filter != null && filter.fieldsToRead != null && filter.fieldsToRead!.isNotEmpty) {
          //Проставить полям из списка признак того, что она пустые - не прочитаны с БД
          //TODO: спорное решение иметь список  пустых полей, чем это лучше значения по-умолчанию?
          for (var fieldName in newItems.first.fieldList.fields.keys) {
            if (filter.fieldsToRead!.contains(fieldName)) continue;
            for (var item in newItems) {
              item.setFieldEmpty(fieldName);
            }
          }
        }
        //TODO: При использовании списка полей для чтения, решить вопрос кэша.
        //А если там уже есть такой же элемент с ранее дочитанными полями?
        if (useCache) {
          NsgDataClient.client.addItemsToCache(items: newItems, tag: tag);
        }
      } else if (name == 'resultsCount') {
        totalCount = int.tryParse(data);
      } else {
        // var foundField = NsgDataClient.client.getReferentFieldByFullPath(dataItemType, name);
        // if (foundField != null) {
        //   var refItems = <NsgDataItem>[];
        //   data.forEach((m) {
        //     if (foundField is NsgDataUntypedReferenceField) {
        //       // var elem = NsgDataClient.client.getNewObject(foundField.referentElementType!);
        //       // elem.fromJson(m as Map<String, dynamic>);
        //       // refItems.add(elem);
        //     } else {
        //       var elem = NsgDataClient.client.getNewObject(foundField.referentElementType);
        //       elem.fromJson(m as Map<String, dynamic>);
        //       refItems.add(elem);
        //     }
        //   });
        //   allItems.addAll(refItems);
        //   if (foundField is NsgDataReferenceListField) {
        //     for (var tabItem in refItems) {
        //       var ownerItem = allItems.firstWhere((e) => tabItem.ownerId == e.id);
        //       foundField.addRow(ownerItem, tabItem);
        //     }
        //   } else {
        //     if (useCache) {
        //       NsgDataClient.client.addItemsToCache(items: refItems, tag: tag);
        //     }
        //   }
        // } else
        {
          if (name.isNotEmpty) {
            name = name.replaceRange(0, 1, name.substring(0, 1).toUpperCase());
          }
          if (NsgDataClient.client.isRegisteredByServerName(name)) {
            var refItems = <NsgDataItem>[];
            data.forEach((m) {
              var elem = NsgDataClient.client.getNewObject(NsgDataClient.client.getTypeByServerName(name));
              elem.fromJson(m as Map<String, dynamic>);
              elem.state = NsgDataItemState.fill;
              refItems.add(elem);
            });
            if (useCache) {
              NsgDataClient.client.addItemsToCache(items: refItems, tag: tag);
            }
          } else {
            debugPrint('ERROR: $dataItemType.$name not found');
          }
        }
      }
    });
    //TODO: отключить после исправления дочитывания (пример - hardwareId в ticket.address.hardware)
    await loadAllReferents(newItems, loadReference, tag: tag);
    return newItems;
  }

  ///Добавить в вписок все ссылочные типа объекта типа type
  ///Если среди полей будет табличная часть, ее ссылочные поля также будут
  ///добавлены в список через имяТаблицы.имяПоля
  static List<String> addAllReferences(Type type, {List<String> exceptFields = const []}) {
    List<String> loadReference = [];
    var allFields = NsgDataClient.client.getFieldList(type);
    for (var field in allFields.fields.values) {
      if (exceptFields.contains(field.name)) {
        continue;
      }
      if ((field is NsgDataReferenceField || field is NsgDataReferenceListField) && field.name != NsgDataItem.nameOwnerId) {
        loadReference.add(field.name);
      }
      if (field is NsgDataReferenceListField) {
        var tableRefereces = addAllReferences(field.referentElementType);
        for (var item in tableRefereces) {
          loadReference.add(field.name + '.' + item);
        }
      }
    }
    return loadReference;
  }

  ///Оснорвной метод запроса данных
  ///Выполняет запрос по стандартному методу, заданному в объекте
  ///Можно перекрыть для изменения логики запроса
  ///filter = доп. фильтр, особенное внимание следует обратить на его сво-во compare
  ///autoAuthorize - переход на авторизацию, если будет получен отказ в доступе
  ///tag - доп признак для кэширования
  ///loadReference - список полей для дочитывания, можно передавать через точку, null - будут дочитаны все поля
  ///                ссылочного типа первого уровн, пустой массив - не будет дочитано ничего
  ///                Обратите внимание, по умолчанию дочитываются все поля, что может негативно сказаться на производительности
  ///function - url вызываемого метода, если не задан, будет взят url данного объекта по умолчанию
  ///method - метод запроса. Рекомендуем всегда использовать POST из-за отсутствия ограничений на передаваемые параметры
  ///addCount - в фильтр будет добавлено ограничение считываемых объектов до одного
  ///postData - передаваемые данные. Не рекомендуется использовать напрямую
  ///autoRepeate - повторять ли запрос в случае ошибки связи
  ///autoRepeateCount - максимальное количество повторов
  ///retryIf - функция, вызываемая перед каждым повторным вызовом. Если вернет false, повторы будут остановлены
  ///onRetry - функция, вызываемая при каждом повторе запроса
  ///requestRegime - режим запроса. Позволяет определить для чего загружаются данные при перекрытии логики данного метода
  Future<T> requestItem(
      {NsgDataRequestParams? filter,
      bool autoAuthorize = true,
      String tag = '',
      List<String>? loadReference,
      String function = '',
      String method = 'GET',
      bool addCount = true,
      dynamic postData,
      bool autoRepeate = false,
      int autoRepeateCount = 1000,
      FutureOr<bool> Function(Exception)? retryIf,
      FutureOr<void> Function(Exception)? onRetry,
      NsgCancelToken? cancelToken}) async {
    NsgDataRequestParams? newFilter;
    if (addCount) {
      if (filter == null) {
        newFilter = NsgDataRequestParams(count: 1);
      } else {
        newFilter = NsgDataRequestParams(
            top: filter.top, count: 1, params: filter.params, sorting: filter.sorting, readNestedField: filter.readNestedField, compare: filter.compare);
      }
    }
    var data = await requestItems(
        filter: newFilter,
        autoAuthorize: autoAuthorize,
        tag: tag,
        loadReference: loadReference,
        function: function,
        method: method,
        postData: postData,
        autoRepeate: autoRepeate,
        autoRepeateCount: autoRepeateCount,
        userRetryIf: _retryIfInternal,
        userOnRetry: onRetry,
        cancelToken: cancelToken);
    if (data.isEmpty) {
      return NsgDataClient.client.getNewObject(dataItemType) as T;
    }
    return data[0];
  }

  Future loadAllReferents(List<NsgDataItem> items, List<String>? loadReference, {String tag = '', bool readTableParts = false}) async {
    if (items.isEmpty || loadReference == null || loadReference.isEmpty) {
      return;
    }
    try {
      for (var fieldName in loadReference) {
        var splitedName = fieldName.split('.');
        var field = NsgDataClient.client.getReferentFieldByFullPath(items[0].runtimeType, splitedName[0]);
        if (field is! NsgDataBaseReferenceField) continue;
        var refList = <String>[];
        var refItems = <NsgDataItem>[];
        var checkItems = <NsgDataItem>[];

        if (field is NsgDataReferenceField) {
          for (var item in items) {
            var checkedItem = field.getReferent(item, allowNull: true);
            if (checkedItem == null) {
              var fieldValue = item.getFieldValue(fieldName).toString();
              if (!fieldValue.contains(Guid.Empty) && (!refList.contains(fieldValue))) {
                refList.add(fieldValue);
              }
            } else {
              checkItems.add(checkedItem);
            }
          }

          if (refList.isNotEmpty && field is! NsgDataUntypedReferenceField) {
            var request = NsgDataRequest(dataItemType: field.referentElementType);
            var cmp = NsgCompare();
            cmp.add(
                name: NsgDataClient.client.getNewObject(field.referentElementType).primaryKeyField,
                value: refList,
                comparisonOperator: NsgComparisonOperator.inList);
            var filter = NsgDataRequestParams(compare: cmp);
            if (storageType == NsgDataStorageType.server) {
              refItems = await request.requestItems(filter: filter, loadReference: []);
            } else {
              refItems = await NsgLocalDb.instance.requestItems(NsgDataClient.client.getNewObject(field.referentElementType), filter);
            }
            checkItems.addAll(refItems);
          }
        } else if (field is NsgDataReferenceListField) {
          for (var item in items) {
            var fieldValue = item.getFieldValue(splitedName[0]) as List<NsgDataItem>;
            if (readTableParts) {
              if (fieldValue.isNotEmpty) {
                var cmp = NsgCompare();
                var ids = <String>[];
                for (var e in fieldValue) {
                  ids.add(e.id);
                }
                cmp.add(name: fieldValue[0].primaryKeyField, value: ids, comparisonOperator: NsgComparisonOperator.inList);
                var request = NsgDataRequest(dataItemType: fieldValue[0].runtimeType, storageType: NsgDataStorageType.local);
                var rows = await request.requestItems(filter: NsgDataRequestParams(compare: cmp));
                for (var row in rows) {
                  var tr = fieldValue.firstWhereOrNull((e) => e.id == row.id);
                  if (tr != null) {
                    tr.copyFieldValues(row);
                  }
                }
              }
            }
            refItems.addAll(fieldValue);
            checkItems.addAll(fieldValue);
          }
        }

        if (splitedName.length > 1 && checkItems.isNotEmpty) {
          splitedName.removeAt(0);
          await loadAllReferents(checkItems, [splitedName.join('.')], tag: tag);
        }
      }
    } catch (ex) {
      debugPrint('ERROR LAR-375: $ex');
    }
  }

  FutureOr<bool> _retryIfInternal(Exception ex) async {
    //400 - код ошибки сервера, не предполагающий повторного запроса данных
    if (ex is NsgApiException && (ex.error.code == 400 || ex.error.code == 401 || ex.error.code == 500)) {
      return false;
    }
    if (retryIf != null) return (await retryIf!(ex));
    return true;
  }
}
