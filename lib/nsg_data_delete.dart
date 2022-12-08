import 'package:nsg_data/nsg_data.dart';

class NsgDataDelete<T extends NsgDataItem> {
  List<T> itemsToDelete;
  Type dataItemType = NsgDataItem;

  NsgDataDelete({this.dataItemType = NsgDataItem, required this.itemsToDelete});

  List<Map<String, dynamic>> _toJson() {
    var list = <Map<String, dynamic>>[];
    for (var i in itemsToDelete) {
      var map = <String, dynamic>{};
      map[i.primaryKeyField] = i.id;
      list.add(map);
    }
    return list;
  }

  Future deleteItems({bool autoAuthorize = true, String tag = '', List<String>? loadReference, String function = ''}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);

    var header = <String, String?>{};
    if (dataItem.remoteProvider.token != '') {
      header['Authorization'] = dataItem.remoteProvider.token;
    }
    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiDeleteItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }

    await dataItem.remoteProvider.baseRequestList(
        function: '$function ${dataItem.runtimeType}',
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: function,
        postData: _toJson(),
        method: 'POST');
  }
}
