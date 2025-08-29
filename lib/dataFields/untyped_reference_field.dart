import 'package:nsg_data/nsg_data.dart';

class NsgDataUntypedReferenceField extends NsgDataReferenceField {
  NsgDataUntypedReferenceField(super.name, {this.defaultReferentType = NsgDataItem});

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  @override
  Type get referentElementType => NsgDataItem;

  @override
  Type get referentType => NsgDataItem;

  ///Объект какого типа возвращать, если будет рапрошен метод getReferent у незаполненной ссылки
  Type defaultReferentType;

  @override
  NsgDataItem? getReferent(NsgDataItem dataItem, {bool useCache = true, bool allowNull = false}) {
    var id = dataItem.getFieldValue(name).toString();
    var uid = UntypedId(id);

    //Если тип не указан, возвращаем null
    if (uid.referentType == null) {
      if (allowNull) {
        return null;
      } else {
        return NsgDataClient.client.getNewObject(defaultReferentType);
      }
    }
    if (uid.guid == Guid.Empty || uid.guid == '') {
      return NsgDataClient.client.getNewObject(uid.referentType!);
    }
    if (useCache) {
      var item = NsgDataClient.client.getItemsFromCache(uid.referentType!, uid.guid, allowNull: allowNull);
      return item;
    } else {
      if (allowNull) {
        return null;
      } else {
        return NsgDataClient.client.getNewObject(defaultReferentType);
      }
    }
  }

  NsgDataItem? getNewReferent(NsgDataItem dataItem) {
    var id = dataItem.getFieldValue(name).toString();
    var uid = UntypedId(id);
    if (uid.referentType == null) return null;
    return NsgDataClient.client.getNewObject(uid.referentType!);
  }

  @override
  Future<NsgDataItem> getReferentAsync(NsgDataItem dataItem, {bool useCache = true}) async {
    var item = getReferent(dataItem, useCache: useCache);
    if (item == null) {
      var id = dataItem.getFieldValue(name).toString();
      var uid = UntypedId(id);
      assert(uid.referentType != null, 'Запрос getReferent у untypedReference с невыбранным типом');

      var cmp = NsgCompare();
      cmp.add(name: name, value: uid.guid);
      var filter = NsgDataRequestParams(compare: cmp);
      var request = NsgDataRequest(dataItemType: uid.referentType!);
      await request.requestItems(filter: filter);
      item = NsgDataClient.client.getItemsFromCache(uid.referentType!, uid.guid);
    }
    return item!;
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name).toString();
    var valueB = b.getFieldValue(name).toString();
    return valueA.compareTo(valueB);
  }
}

///Идентификатор ссылки  неопределенного типа.
///Должен состооять из идентификатора и типа данных, разделенными точкой. Например,
///GUID.ExanpleItem
class UntypedId {
  String guid = '';
  Type? referentType;

  UntypedId(String id) {
    //print('UUID = $id');
    if (id == '') {
      return;
    }
    var idSplitted = id.split('.');
    assert(idSplitted.length <= 2, 'Id untyped reference не может соодержать больше 2 частей (guid.type)');
    guid = idSplitted[0];
    if (idSplitted.length == 2) {
      referentType = idSplitted[1].isEmpty ? null : NsgDataClient.client.getTypeByServerName(idSplitted[1]);
    }
  }
}
