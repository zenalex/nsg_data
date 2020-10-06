import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nsg_data_client.dart';
import 'nsg_data_item.dart';
import 'nsg_data_request_filter.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items;

  void _fromJson(Map<String, dynamic> json) {
    if (json['Items'] != null) {
      items = <T>[];
      json['Items'].forEach((v) {
        var elem = NsgDataClient.client.getNewObject(T);
        elem.fromJson(v as Map<String, dynamic>);
        items.add(elem as T);
      });
    }
  }

  Future<NsgDataRequest<T>> requestItems(
      {NsgDataRequestFilter filter, bool autoAuthorize = true}) async {
    var dataItem = NsgDataClient.client.getNewObject(T);
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
    if (response.statusCode == 200) {
      _fromJson(json.decode(response.body) as Map<String, dynamic>);
      return this;
    } else if (response.statusCode == 401) {
      throw Exception('Authorization error. Request items failed.');
    } else {
      throw Exception(
          'Request items failed, error code is ${response.statusCode}');
    }
  }
}
