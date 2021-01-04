import 'package:nsg_data/nsg_data.dart';
import 'nsg_data_client.dart';

class NsgDataPost<T extends NsgDataItem> {
  List<T> itemsToPost;
  List<T> _items;
  Type dataItemType;

  NsgDataPost({this.dataItemType}) {
    dataItemType ??= T;
  }

  void _fromJsonList(List<dynamic> maps) {
    _items = <T>[];
    maps.forEach((m) {
      var elem = NsgDataClient.client.getNewObject(dataItemType);
      elem.fromJson(m as Map<String, dynamic>);
      _items.add(elem as T);
    });
  }

  List<Map<String, dynamic>> _toJson() {
    var list = <Map<String, dynamic>>[];
    itemsToPost.forEach((i) {
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

    // final _dio = Dio(BaseOptions(
    //   headers: header,
    //   method: 'POST',
    //   responseType: ResponseType.json,
    //   contentType: 'application/json',
    //   connectTimeout: 15000,
    //   receiveTimeout: 15000,
    // ));
    //var test = await _dio.post(function, data: _toJson());

    var response = await dataItem.remoteProvider.baseRequestList(
        function: '$function ${dataItem.runtimeType}',
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: function,
        postData: _toJson(),
        method: 'POST');

    if (response is List<dynamic>) {
      _fromJsonList(response);
      NsgDataClient.client.addItemsToCache(items: _items, tag: tag);
    }
    //Check referent field list
    if (loadReference != null && _items != null) {
      var req = NsgDataRequest<T>();
      await req.loadAllReferents(_items, loadReference, tag: tag);
    }
    return _items;
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
