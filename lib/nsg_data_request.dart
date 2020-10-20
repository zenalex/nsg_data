import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nsg_data/dataFields/referenceField.dart';
import 'nsg_data_client.dart';
import 'nsg_data_item.dart';
import 'nsg_data_request_filter.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items;
  Type dataItemType;

  NsgDataRequest({this.dataItemType}) {
    dataItemType ??= T;
  }

  void _fromJson(Map<String, dynamic> json) {
    if (json['Items'] != null) {
      items = <T>[];
      json['Items'].forEach((v) {
        var elem = NsgDataClient.client.getNewObject(dataItemType);
        elem.fromJson(v as Map<String, dynamic>);
        items.add(elem as T);
      });
    }
  }

  Future<NsgDataRequest<T>> requestItems(
      {NsgDataRequestFilter filter,
      bool autoAuthorize = true,
      String tag,
      List<String> loadReference}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);
    var filterMap = <String, String>{};
    if (filter != null) filterMap = filter.toJson();
    var header = <String, String>{};
    if (dataItem.remoteProvider.token != '') {
      header['Authorization'] = dataItem.remoteProvider.token;
    }
    var response = await http
        .post(dataItem.remoteProvider.serverUri + dataItem.apiRequestItems,
            headers: header, body: filterMap)
        .catchError((e) {
      print(e);
    });
    if (response != null) {
      if (response.statusCode == 200) {
        _fromJson(json.decode(response.body) as Map<String, dynamic>);
        NsgDataClient.client.addItemsToCache(items: items, tag: tag);
        //Check referent field list
        if (loadReference != null) {
          await loadAllReferents(items, loadReference, tag: tag);
        }
        return this;
      } else if (response.statusCode == 401) {
        throw Exception('Authorization error. Request items failed.');
      }
    }
    var errorCode = response == null ? 'unknown' : response.statusCode;
    throw Exception('Request items failed, error code is ${errorCode}');
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
      var filter = NsgDataRequestFilter(idList: allRefs[type]);
      await request.requestItems(filter: filter);
    });
  }
}
