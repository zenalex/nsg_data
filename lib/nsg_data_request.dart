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
        elem.fromJson(v);
        items.add(elem);
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
      _fromJson(json.decode(response.body));
      return this;
    } else if (response.statusCode == 401) {
      //Authorization error
      if (autoAuthorize) {
        await dataItem.remoteProvider.getToken();
        return await requestItems(filter: filter, autoAuthorize: false);
      }
    }
    throw Exception(
        'request items failed, error code is ${response.statusCode}');
  }
}
