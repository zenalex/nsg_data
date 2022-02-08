import '../nsg_data.dart';

class NsgDataReferenceListField<T extends NsgDataItem> extends NsgDataField {
  NsgDataReferenceListField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => <T>[];

  Type get referentType => List<T>;

  List<T>? getReferent(NsgDataItem dataItem, {bool useCache = true}) {
    return null;

    // var id = dataItem.getFieldValue(name).toString();
    // if (id == '' || id == NsgDataItem.ZERO_GUID) {
    //   return NsgDataClient.client.getNewObject(T) as T;
    // }
    // if (useCache) {
    //   var item = NsgDataClient.client.getItemsFromCache(T, id) as T?;
    //   return item;
    // } else {
    //   return null;
    // }
  }

  Future<List<T>> getReferentAsync(NsgDataItem dataItem,
      {bool useCache = true}) async {
    var item = getReferent(dataItem, useCache: useCache);
    if (item == null) {
      var id = dataItem.getFieldValue(name).toString();
      var filter = NsgDataRequestParams(idList: [id, id]);
      var request = NsgDataRequest<T>();
      item = await request.requestItems(filter: filter);
    }
    return item;
  }

  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is List) {
      fieldValues.fields[name] = value;
    } else {
      fieldValues.fields[name] = defaultValue;
    }
  }
}
