import 'package:either_option/either_option.dart';
import 'package:nsg_data/dataFields/referenceField.dart';
import 'package:nsg_data/nsgDataApiError.dart';
import 'nsg_data_client.dart';
import 'nsg_data_item.dart';
import 'nsg_data_request_filter.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items;
  Type dataItemType;

  NsgDataRequest({this.dataItemType}) {
    dataItemType ??= T;
  }

  void _fromJson(Map<String, dynamic> json) {
    if (json['Items'] != null) {
      items = <T>[];
      json['Items'].forEach((v) {
        var elem = NsgDataClient.client.getNewObject(dataItemType);
        elem.fromJson(v as Map<String, dynamic>);
        items.add(elem as T);
      });
    }
  }

  Future<Either<NsgApiError, List<T>>> requestItems(
      {NsgDataRequestFilter filter,
      bool autoAuthorize = true,
      String tag,
      List<String> loadReference}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);
    var filterMap = <String, String>{};
    if (filter != null) filterMap = filter.toJson();
    var header = <String, String>{};
    if (dataItem.remoteProvider.token != '') {
      header['Authorization'] = dataItem.remoteProvider.token;
    }
    var response = await dataItem.remoteProvider.baseRequest(
        function: 'apiRequestItems ${dataItem.runtimeType}',
        headers: dataItem.remoteProvider.getAuthorizationHeader(),
        url: dataItem.remoteProvider.serverUri + dataItem.apiRequestItems,
        method: 'POST',
        params: filterMap);

    NsgApiError error;
    response.fold((e) => error = e, (data) {
      _fromJson(data);
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);
    });
    if (response.isRight) {
      //Check referent field list
      if (loadReference != null) {
        await loadAllReferents(items, loadReference, tag: tag);
      }
    }
    return response.fold((e) => Left(error), (data) => Right(items));
  }

  Future loadAllReferents(List<T> items, List<String> loadReference,
      {String tag}) async {
    if (items == null || items.isEmpty) {
      return;
    }
    var allRefs = <Type, List<String>>{};
    items.forEach((item) {
      loadReference.forEach((fieldName) {
        var field = item.fieldList.fields[fieldName];
        if (field is NsgDataReferenceField) {
          if (field.getReferent(item) == null) {
            var fieldType =
                (item.fieldList.fields[fieldName] as NsgDataReferenceField)
                    .referentType;
            var fieldValue = item.getFieldValue(fieldName).toString();
            if (!allRefs.containsKey(fieldType)) {
              allRefs[fieldType] = <String>[];
            }
            var refList = allRefs[fieldType];
            if (!refList.contains(fieldValue)) {
              refList.add(fieldValue);
            }
          }
        }
      });
    });
    await Future.forEach<Type>(allRefs.keys, (type) async {
      var request = NsgDataRequest(dataItemType: type);
      var filter = NsgDataRequestFilter(idList: allRefs[type]);
      await request.requestItems(filter: filter);
    });
  }
}
