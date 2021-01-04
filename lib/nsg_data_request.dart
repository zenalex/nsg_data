import 'dart:async';

import 'package:nsg_data/dataFields/referenceField.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:retry/retry.dart';
import 'nsg_data_client.dart';
import 'nsg_data_item.dart';
import 'nsg_data_requestParams.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items;
  Type dataItemType;

  NsgDataRequest({this.dataItemType}) {
    dataItemType ??= T;
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
      {NsgDataRequestParams filter,
      bool autoAuthorize = true,
      String tag,
      List<String> loadReference,
      String function = '',
      String method = 'GET',
      dynamic postData,
      bool autoRepeate = false,
      int autoRepeateCount = 1000,
      FutureOr<bool> Function(Exception) retryIf,
      FutureOr<void> Function(Exception) onRetry}) async {
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
    NsgDataRequestParams filter,
    bool autoAuthorize = true,
    String tag,
    List<String> loadReference,
    String function = '',
    String method = 'GET',
    dynamic postData,
  }) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);
    var filterMap = <String, String>{};
    if (filter != null) filterMap = filter.toJson();
    var header = <String, String>{};
    if (dataItem.remoteProvider.token != '') {
      header['Authorization'] = dataItem.remoteProvider.token;
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

    _fromJsonList(response as List<dynamic>);
    NsgDataClient.client.addItemsToCache(items: items, tag: tag);
    if (loadReference == null && dataItem.loadReferenceDefault != null) {
      loadReference = dataItem.loadReferenceDefault;
    }
    //Check referent field list
    if (loadReference != null) {
      await loadAllReferents(items, loadReference, tag: tag);
    }
    return items;
  }

  Future<T> requestItem(
      {NsgDataRequestParams filter,
      bool autoAuthorize = true,
      String tag,
      List<String> loadReference,
      String function = '',
      String method = 'GET',
      bool addCount = true,
      dynamic postData}) async {
    NsgDataRequestParams newFilter;
    if (addCount) {
      if (filter == null) {
        newFilter = NsgDataRequestParams(count: 1);
      } else {
        newFilter = NsgDataRequestParams(
            top: filter.top,
            count: 1,
            idList: filter.idList,
            params: filter.params);
      }
    }
    var data = await requestItems(
        filter: newFilter,
        autoAuthorize: autoAuthorize,
        tag: tag,
        loadReference: loadReference,
        function: function,
        method: method,
        postData: postData);
    if (data == null || data.isEmpty) {
      return null;
    }
    return data[0];
  }

  Future loadAllReferents(List<T> items, List<String> loadReference,
      {String tag}) async {
    if (items == null || items.isEmpty) {
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
            var refList = allRefs[fieldType];
            if (!refList.contains(fieldValue)) {
              refList.add(fieldValue);
            }
          }
        }
      });
    });
    await Future.forEach<Type>(allRefs.keys, (type) async {
      var request = NsgDataRequest(dataItemType: type);
      var filter = NsgDataRequestParams(idList: allRefs[type]);
      await request.requestItems(filter: filter);
    });
  }
}
