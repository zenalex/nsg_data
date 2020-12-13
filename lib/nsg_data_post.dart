import 'package:nsg_data/nsg_data.dart';
import 'nsgDataApiError.dart';
import 'nsg_data_client.dart';

class NsgDataPost<T extends NsgDataItem> {
  List<T> items;
  Type dataItemType;

  NsgDataPost({this.dataItemType}) {
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

  List<Map<String, dynamic>> _toJson() {
    var list = <Map<String, dynamic>>[];
    items.forEach((i) {
      list.add(i.toJson());
    });
    return list;
  }

  Future<List<T>> postItems(
      {bool autoAuthorize = true,
      String tag,
      List<String> loadReference,
      String function = ''}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);

    var header = <String, String>{};
    if (dataItem.remoteProvider.token != '') {
      header['Authorization'] = dataItem.remoteProvider.token;
    }
    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiPostItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }
    var response = await dataItem.remoteProvider.baseRequestList(
        function: '$function ${dataItem.runtimeType}',
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: function,
        postData: _toJson(),
        method: 'POST');

    NsgApiError error;
    response.fold((e) => error = e, (data) {
      _fromJsonList(data);
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);
    });
    if (response.isRight) {
      //Check referent field list
      if (loadReference != null) {
        var req = NsgDataRequest<T>();
        await req.loadAllReferents(items, loadReference, tag: tag);
      }
    }
    response.fold((e) => throw NsgApiException(error), (data) {});
    return items;
  }

  Future<T> postItem({
    bool autoAuthorize = true,
    String tag,
    List<String> loadReference,
    String function = '',
  }) async {
    var data = await postItems(
        autoAuthorize: autoAuthorize,
        tag: tag,
        loadReference: loadReference,
        function: function);
    if (data == null || data.isEmpty) {
      return null;
    }
    return data[0];
  }
}
