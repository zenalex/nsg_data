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
    for (var i in itemsToPost) {
      list.add(i.toJson());
    }
    return list;
  }

  Future<List<T>> postItems({bool autoAuthorize = true, String tag = '', List<String>? loadReference, String function = ''}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);

    ///для объектов с запретом массового POST вызываем последовательное сохранение каждого объекта
    if (dataItem.postArrayIsForbidden) {
      for (var item in itemsToPost) {
        await item.post();
      }
      return itemsToPost;
    }
    var header = <String, String?>{};
    if (dataItem.remoteProvider.token != '') {
      header['Authorization'] = dataItem.remoteProvider.token;
    }
    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiPostItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }

    Map<String, dynamic>? filterMap;
    //Добавим поля для дочитывания
    if (loadReference != null) {
      var filter = NsgDataRequestParams();
      filter.referenceList = loadReference;
      filterMap = filter.toJson();
    }
    var response = await dataItem.remoteProvider.baseRequestList(
      function: '$function ${dataItem.runtimeType}',
      headers: dataItem.remoteProvider.getAuthorizationHeader(),
      url: function,
      postData: _toJson(),
      method: 'POST',
      params: filterMap,
    );

    var req = NsgDataRequest<T>(dataItemType: dataItemType);
    _items = (await req.loadDataAndReferences(response, loadReference ?? [], tag)).cast();
    for (var element in _items) {
      element.state = NsgDataItemState.fill;
    }
    return _items;
  }

  Future<T?> postItem({bool autoAuthorize = true, String tag = '', List<String>? loadReference, String function = ''}) async {
    var data = await postItems(autoAuthorize: autoAuthorize, tag: tag, loadReference: loadReference, function: function);
    if (data.isEmpty) {
      return null;
    }
    return data[0];
  }
}
