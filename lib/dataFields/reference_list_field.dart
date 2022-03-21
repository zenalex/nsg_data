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
  Type get referentElementType => T;

  List<T>? getReferent(NsgDataItem dataItem, {bool useCache = true}) {
    return dataItem.getFieldValue(name);

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
      var cmp = NsgCompare();
      cmp.add(name: name, value: id);
      var filter = NsgDataRequestParams(compare: cmp);
      var request = NsgDataRequest<T>();
      item = await request.requestItems(filter: filter);
    }
    return item;
  }

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is List) {
      fieldValues.fields[name] = fromJsonList(value);
    } else {
      fieldValues.fields[name] = defaultValue;
    }
  }

  List<T> fromJsonList(List<dynamic> maps) {
    var items = <T>[];
    maps.forEach((m) {
      var elem = NsgDataClient.client.getNewObject(referentElementType);
      elem.fromJson(m as Map<String, dynamic>);
      items.add(elem as T);
    });
    return items;
  }
}
