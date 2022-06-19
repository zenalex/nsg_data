import 'package:nsg_data/nsg_data.dart';

import '../helpers/nsg_data_guid.dart';

class NsgDataReferenceField<T extends NsgDataItem> extends NsgDataBaseReferenceField {
  NsgDataReferenceField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  @override
  Type get referentElementType => T;

  Type get referentType => T;

  T? getReferent(NsgDataItem dataItem, {bool useCache = true, bool allowNull = false}) {
    var id = dataItem.getFieldValue(name).toString();
    if (id == '' || id == Guid.Empty) {
      return NsgDataClient.client.getNewObject(T) as T;
    }
    if (useCache) {
      var item = NsgDataClient.client.getItemsFromCache(T, id, allowNull: allowNull) as T?;
      return item;
    } else {
      return null;
    }
  }

  Future<T> getReferentAsync(NsgDataItem dataItem, {bool useCache = true}) async {
    var item = getReferent(dataItem, useCache: useCache);
    if (item == null) {
      var id = dataItem.getFieldValue(name).toString();
      var cmp = NsgCompare();
      cmp.add(name: name, value: id);
      var filter = NsgDataRequestParams(compare: cmp);
      var request = NsgDataRequest<T>();
      await request.requestItems(filter: filter);
      item = NsgDataClient.client.getItemsFromCache(T, id) as T?;
    }
    return item!;
  }
}
