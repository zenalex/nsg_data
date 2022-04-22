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

  void _fromJsonList(List<dynamic> maps) {
    items = <T>[];
    maps.forEach((m) {
      var elem = NsgDataClient.client.getNewObject(dataItemType);
      elem.fromJson(m as Map<String, dynamic>);
      items.add(elem as T);
    });
  }

  Future<List<T>> requestItems(
      {NsgDataRequestParams? filter,
      bool autoAuthorize = true,
      String tag = '',
      List<String>? loadReference,
      String function = '',
      String method = 'GET',
      dynamic postData,
      bool autoRepeate = false,
      int autoRepeateCount = 1000,
      FutureOr<bool> Function(Exception)? retryIf,
      FutureOr<void> Function(Exception)? onRetry}) async {
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
              postData: postData),
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
          postData: postData);
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
    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiRequestItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }
    var url = '$function';
    var isLoadReferenceMode = false;
    if (loadReference.isNotEmpty) {
      url += '/References';
      isLoadReferenceMode = true;
    }

    var response = await dataItem.remoteProvider.baseRequestList(
        function: url,
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: url,
        method: method,
        params: filterMap,
        postData: postData);
    items = <T>[];
    try {
      if (response == '' || response == null) {
      } else {
        if (isLoadReferenceMode) {
          var maps = response as Map<String, dynamic>;
          maps.forEach((name, data) {
            if (name == "results") {
              _fromJsonList(data);
              NsgDataClient.client.addItemsToCache(items: items, tag: tag);
            } else {
              var fullPath = name.split('.');
              var type = dataItemType;
              var fieldFound = false;
              for (var i = 0; i < fullPath.length; i++) {
                fieldFound = false;
                var fieldList = NsgDataClient.client.getFieldList(type);
                if (fieldList.fields.containsKey(fullPath[i])) {
                  var field = fieldList.fields[fullPath[i]];
                  if (field is NsgDataReferenceField) {
                    type = field.referentType;
                    fieldFound = true;
                  } else if (field is NsgDataReferenceListField) {
                    type = field.referentElementType;
                    fieldFound = true;
                  }
                }
              }
              if (fieldFound) {
                var refItems = <NsgDataItem>[];
                data.forEach((m) {
                  var elem = NsgDataClient.client.getNewObject(type);
                  elem.fromJson(m as Map<String, dynamic>);
                  refItems.add(elem as T);
                });
                NsgDataClient.client.addItemsToCache(items: refItems, tag: tag);
              } else {
                print('ERROR: $dataItemType.$fullPath not found');
              }
            }
          });
        } else {
          if (!(response is List)) {
            response = <dynamic>[response];
          }
          _fromJsonList(response);
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
            top: filter.top,
            count: 1,
            params: filter.params,
            sorting: filter.sorting,
            readNestedField: filter.readNestedField,
            compare: filter.compare);
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
        onRetry: onRetry);
    if (data.isEmpty) {
      return NsgDataClient.client.getNewObject(dataItemType) as T;
    }
    return data[0];
  }

  Future loadAllReferents(
      List<NsgDataItem> items, List<String>? loadReferenceExt,
      {String tag = ''}) async {
    if (items.isEmpty) {
      return;
    }
    List<String> loadReference = loadReferenceExt ?? [];

    //if there are no items or loadReference list is empty do nothing
    if (loadReference.isEmpty) {
      return;
    }
    var allRefs = <Type, List<String>>{};
    items.forEach((item) {
      loadReference.forEach((fieldName) {
        var field = item.fieldList.fields[fieldName];
        if (field is NsgDataReferenceField) {
          if (field.getReferent(item, allowNull: true) == null) {
            var fieldType =
                (item.fieldList.fields[fieldName] as NsgDataReferenceField)
                    .referentType;
            var fieldValue = item.getFieldValue(fieldName).toString();
            if (!allRefs.containsKey(fieldType)) {
              allRefs[fieldType] = <String>[];
            }
            var refList = allRefs[fieldType]!;
            if (!refList.contains(fieldValue)) {
              refList.add(fieldValue);
            }
          }
        }
      });
    });
    await Future.forEach<Type>(allRefs.keys, (type) async {
      var request = NsgDataRequest(dataItemType: type);
      var cmp = NsgCompare();
      cmp.add(
          name: NsgDataClient.client.getNewObject(type).primaryKeyField,
          value: allRefs[type],
          comparisonOperator: NsgComparisonOperator.inList);
      var filter = NsgDataRequestParams(compare: cmp);
      var refItems = await request.requestItems(filter: filter);
      loadAllReferents(refItems, loadReference, tag: tag);
    });
  }
}
