import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:retry/retry.dart';
import 'nsg_comparison_operator.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items = <T>[];
  Type dataItemType;

  NsgDataRequest({this.dataItemType = NsgDataItem}) {
    if (dataItemType == NsgDataItem) dataItemType = T;
  }

  List<NsgDataItem> _fromJsonList(List<dynamic> maps) {
    var items = <T>[];
    maps.forEach((m) {
      var elem = NsgDataClient.client.getNewObject(dataItemType);
      elem.fromJson(m as Map<String, dynamic>);
      items.add(elem as T);
    });
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
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
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
              ),
          retryIf: retryIf,
          onRetry: onRetry);
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
      );
    }
  }

  Future<List<T>> _requestItems({
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    List<String>? loadReference,
    String function = '',
    String method = 'GET',
    Map<String, dynamic>? postData,
  }) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);
    var filterMap = <String, dynamic>{};

    //Добавление в запрос имен полей, требующих дочитывания
    if (loadReference == null && dataItem.loadReferenceDefault != null) {
      loadReference = dataItem.loadReferenceDefault;
    }
    if (loadReference == null) {
      loadReference = [];
      loadReference = _addAllReferences(dataItem.runtimeType);
    }
    if (filter == null) {
      filter = NsgDataRequestParams();
    }
    filter.readNestedField = loadReference.join(',');

    method = 'POST';
    if (method == 'GET') {
      filterMap = filter.toJson();
    } else {
      if (postData == null) postData = {};
      postData.addAll(filter.toJson());
    }

    //Режим работы без дочитывания удален как неиспользуемый
    //var isLoadReferenceMode = loadReference.isNotEmpty;
    var sufficsRef = loadReference.isEmpty ? '' : '/References';
    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiRequestItems + sufficsRef;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }
    var url = '$function';
    var response = await dataItem.remoteProvider.baseRequestList(
        function: url, headers: dataItem.remoteProvider.getAuthorizationHeader(), url: url, method: method, params: filterMap, postData: postData);
    items = <T>[];
    try {
      if (response == '' || response == null) {
      } else {
        if (response is Map) {
          items = (await loadDataAndReferences(response, loadReference, tag, filter: filter)).cast();
        } else {
          if (!(response is List)) {
            response = <dynamic>[response];
          }
          items = _fromJsonList(response).cast();
          NsgDataClient.client.addItemsToCache(items: items, tag: tag);

          //Check referent field list
          await loadAllReferents(items, loadReference, tag: tag);
        }
      }
    } catch (e) {
      print(e);
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
      if (name == "results") {
        newItems = _fromJsonList(data);
        allItems.addAll(newItems);
        if (newItems.isNotEmpty && filter != null && filter.fieldsToRead != null && filter.fieldsToRead!.isNotEmpty) {
          //Проставить полям из списка признак того, что она пустые - не прочитаны с БД
          for (var fieldName in newItems.first.fieldList.fields.keys) {
            if (filter.fieldsToRead!.contains(fieldName)) continue;
            for (var item in newItems) {
              item.setFieldEmpty(fieldName);
            }
          }
        }
        //TODO: При использовании списка полей для чтения, отключил использование кэш
        if (useCache) {
          NsgDataClient.client.addItemsToCache(items: newItems, tag: tag);
        }
      } else {
        var foundField = NsgDataClient.client.getReferentFieldByFullPath(dataItemType, name);
        if (foundField != null) {
          var refItems = <NsgDataItem>[];
          data.forEach((m) {
            var elem = NsgDataClient.client.getNewObject(foundField.referentElementType);
            elem.fromJson(m as Map<String, dynamic>);
            refItems.add(elem);
          });
          allItems.addAll(refItems);
          if (foundField is NsgDataReferenceListField) {
            for (var tabItem in refItems) {
              var ownerItem = allItems.firstWhere((e) => tabItem.ownerId == e.id);
              foundField.addRow(ownerItem, tabItem);
            }
          } else {
            if (useCache) {
              NsgDataClient.client.addItemsToCache(items: refItems, tag: tag);
            }
          }
        } else {
          print('ERROR: $dataItemType.$name not found');
        }
      }
    });
    await loadAllReferents(newItems, loadReference, tag: tag);
    return newItems;
  }

  ///Добавить в вписок все ссылочные типа объекта типа type
  ///Если среди полей будет табличная часть, ее ссылочные поля также будут
  ///добавлены в список через имяТаблицы.имяПоля
  List<String> _addAllReferences(Type type) {
    List<String> loadReference = [];
    var allFields = NsgDataClient.client.getFieldList(type);
    for (var field in allFields.fields.values) {
      if (field is NsgDataReferenceField) {
        loadReference.add(field.name);
      }
      if (field is NsgDataReferenceListField) {
        var tableRefereces = _addAllReferences(field.referentElementType);
        for (var item in tableRefereces) {
          loadReference.add(field.name + '.' + item);
        }
      }
    }
    return loadReference;
  }

  ///Оснорвной метод запроса данных
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
      FutureOr<void> Function(Exception)? onRetry}) async {
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
      retryIf: retryIf,
      onRetry: onRetry,
    );
    if (data.isEmpty) {
      return NsgDataClient.client.getNewObject(dataItemType) as T;
    }
    return data[0];
  }

  Future loadAllReferents(List<NsgDataItem> items, List<String>? loadReference, {String tag = ''}) async {
    if (items.isEmpty || loadReference == null || loadReference.isEmpty) {
      return;
    }

    for (var fieldName in loadReference) {
      var splitedName = fieldName.split('.');
      var field = NsgDataClient.client.getReferentFieldByFullPath(items[0].runtimeType, splitedName[0]);
      if (!(field is NsgDataBaseReferenceField)) continue;
      var refList = <String>[];
      var refItems = <NsgDataItem>[];

      if (field is NsgDataReferenceField) {
        for (var item in items) {
          if (field.getReferent(item, allowNull: true) == null) {
            var fieldValue = item.getFieldValue(fieldName).toString();
            if (!refList.contains(fieldValue)) {
              refList.add(fieldValue);
            }
          }
        }

        if (refList.isNotEmpty) {
          var request = NsgDataRequest(dataItemType: field.referentElementType);
          var cmp = NsgCompare();
          cmp.add(
              name: NsgDataClient.client.getNewObject(field.referentElementType).primaryKeyField,
              value: refList,
              comparisonOperator: NsgComparisonOperator.inList);
          var filter = NsgDataRequestParams(compare: cmp);
          refItems = await request.requestItems(filter: filter, loadReference: []);
        }
      } else if (field is NsgDataReferenceListField) {
        for (var item in items) {
          var fieldValue = item.getFieldValue(splitedName[0]);
          refItems.addAll(fieldValue as List<NsgDataItem>);
        }
      }

      if (splitedName.length > 1 && refItems.isNotEmpty) {
        splitedName.removeAt(0);
        loadAllReferents(refItems, [splitedName.join('.')], tag: tag);
      }
    }
  }
}
