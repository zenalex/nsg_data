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
    if (filter != null) {
      if (method == 'GET') {
        filterMap = filter.toJson();
      } else {
        if (postData == null) postData = {};
        postData.addAll(filter.toJson());
      }
    }
    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiRequestItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }
    var response = await dataItem.remoteProvider.baseRequestList(
        function: '$function ${dataItem.runtimeType}',
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: function,
        method: method,
        params: filterMap,
        postData: postData);
    items = <T>[];
    if (response == '' || response == null) {
    } else {
      _fromJsonList(response as List<dynamic>);
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);
      if (loadReference == null && dataItem.loadReferenceDefault != null) {
        loadReference = dataItem.loadReferenceDefault;
      }
      //Check referent field list
      await loadAllReferents(items, loadReference,
          tag: tag, readAllReferences: loadReference == null);
    }
    return items;
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
      {String tag = '', bool readAllReferences = false}) async {
    if (items.isEmpty) {
      return;
    }
    List<String> loadReference = loadReferenceExt ?? [];
    //if loadReference == null - try to load all references
    if (readAllReferences) {
      loadReference = [];
      var allFields = NsgDataClient.client.getFieldList(items[0].runtimeType);
      for (var fieldName in allFields.fields.keys) {
        loadReference.add(fieldName);
      }
    }
    //if there are no items or loadReference list is empty do nothing
    if (loadReference.isEmpty) {
      return;
    }
    var allRefs = <Type, List<String>>{};
    items.forEach((item) {
      loadReference.forEach((fieldName) {
        var field = item.fieldList.fields[fieldName];
        if (field is NsgDataReferenceField) {
          if (field.getReferent(item) == null) {
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
        } else if (field is NsgDataReferenceListField) {
          var table = field.getReferent(item);

          if (table == null) {
            //TODO: сделать загрузку самого списка, если он еще не загружен
          } else if (readAllReferences) {
            loadAllReferents(table, [],
                tag: tag, readAllReferences: readAllReferences);
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
      //TODO: 20032002 ПРОВЕРИТЬ
      var refItems = await request.requestItems(filter: filter);
      if (readAllReferences) {
        loadAllReferents(refItems, loadReference,
            tag: tag, readAllReferences: readAllReferences);
      }
    });
  }
}
