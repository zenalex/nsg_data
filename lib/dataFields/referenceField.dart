import 'package:nsg_data/dataFields/datafield.dart';
import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/nsg_data_request.dart';
import 'package:nsg_data/nsg_data_request_filter.dart';

class NsgDataReferenceField<T extends NsgDataItem> extends NsgDataField {
  NsgDataReferenceField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  static const String _ZERO_GUID = '00000000-0000-0000-0000-000000000000';
  T getReferent(NsgDataItem dataItem) {
    var id = dataItem.getFieldValue(name).toString();
    if (id == '' || id == _ZERO_GUID) {
      return NsgDataClient.client.getNewObject(T) as T;
    }
    var item = NsgDataClient.client.getItemsFromCache(T, id) as T;
    return item;
  }

  Future<T> getReferentAsync(NsgDataItem dataItem) async {
    var item = getReferent(dataItem);
    if (item == null) {
      var id = dataItem.getFieldValue(name).toString();
      var filter = NsgDataRequestFilter(idList: [id]);
      var request = NsgDataRequest<T>();
      await request.requestItems(filter: filter);
      item = NsgDataClient.client.getItemsFromCache(T, id) as T;
    }
    return item;
  }
}
