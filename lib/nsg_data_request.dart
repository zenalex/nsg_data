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

  Future<NsgDataRequest<T>> requestItems({NsgDataRequestFilter filter}) async {
    var dataItem = NsgDataClient.client.getNewObject(T);
    Map<String, String> filterMap = {};
    if (filter != null) filterMap = filter.toJson();
    var response = await http
        .post(NsgDataClient.client.serverUri + dataItem.apiRequestItems,
            body: filterMap)
        .timeout(NsgDataClient.client.requestDuration)
        .catchError((e) {
      print(e);
    });
    if (response.statusCode == 200) {
      _fromJson(json.decode(response.body));
      return this;
    } else {
      throw Exception(
          'request items failed, error code is ${response.statusCode}');
    }
  }
}
