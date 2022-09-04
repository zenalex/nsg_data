import 'package:nsg_data/nsg_data.dart';

class NsgDataPost<T extends NsgDataItem> {
  late List<T> itemsToPost;
  List<T> _items = <T>[];
  Type dataItemType = NsgDataItem;

  NsgDataPost({this.dataItemType = NsgDataItem});

  // void _fromJsonList(List<dynamic> maps) {
  //   _items = <T>[];
  //   maps.forEach((m) {
  //     var elem = NsgDataClient.client.getNewObject(dataItemType);
  //     elem.fromJson(m as Map<String, dynamic>);
  //     _items.add(elem as T);
  //   });
  // }

  List<Map<String, dynamic>> _toJson() {
    var list = <Map<String, dynamic>>[];
    itemsToPost.forEach((i) {
      list.add(i.toJson());
    });
    return list;
  }

  Future<List<T>?> postItems({bool autoAuthorize = true, String tag = '', List<String>? loadReference, String function = ''}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);

    var header = <String, String?>{};
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

    var req = NsgDataRequest<T>(dataItemType: dataItemType);
    _items = (await req.loadDataAndReferences(response, loadReference ?? [], tag)).cast();
    for (var element in _items) {
      element.state = NsgDataItemState.fill;
    }
    return _items;
  }

  Future<T?> postItem({
    bool autoAuthorize = true,
    String tag = '',
    List<String>? loadReference,
    String function = '',
  }) async {
    var data = await postItems(autoAuthorize: autoAuthorize, tag: tag, loadReference: loadReference, function: function);
    if (data == null || data.isEmpty) {
      return null;
    }
    return data[0];
  }
}
