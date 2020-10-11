import 'dart:convert';
import 'package:http/http.dart' as http;
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
      String tag}) async {
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
        .timeout(dataItem.remoteProvider.requestDuration)
        .catchError((e) {
      print(e);
    });
    if (response != null && response.statusCode == 200) {
      _fromJson(json.decode(response.body) as Map<String, dynamic>);
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);
      return this;
    } else if (response.statusCode == 401) {
      throw Exception('Authorization error. Request items failed.');
    } else {
      var errorCode = response == null ? 'unknown' : response.statusCode;
      throw Exception('Request items failed, error code is ${errorCode}');
    }
  }
}
