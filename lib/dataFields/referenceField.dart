// ignore_for_file: file_names

import 'package:nsg_data/nsg_data.dart';

class NsgDataReferenceField<T extends NsgDataItem> extends NsgDataBaseReferenceField {
  NsgDataReferenceField(super.name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  @override
  Type get referentElementType => T;

  @override
  Type get referentType => T;

  T? getReferent(NsgDataItem dataItem, {bool useCache = true, bool allowNull = false}) {
    var id = dataItem.getFieldValue(name).toString();
    if (id == '' || id == Guid.Empty) {
      if (allowNull) {
        return null;
      }
      return NsgDataClient.client.getNewObject(T) as T;
    }
    if (useCache) {
      //Спрашиваем кэш с allowNull, даже если вызывающий хочет пустышку: так промах
      //виден здесь, а не подменяется молча новым объектом внутри кэша.
      var item = NsgDataClient.client.getItemsFromCache(T, id, allowNull: true) as T?;
      if (item != null) return item;
      //Ссылка задана, а объекта нет — его не дочитали. Экран получит пустышку и
      //нарисует пустоту без единой ошибки. В удачном пути мы сюда не заходим,
      //поэтому диагностика ничего не стоит и работает в том числе в релизе.
      NsgFieldUsage.reportMissingReferent(dataItem.typeName, name);
      if (allowNull) return null;
      return NsgDataClient.client.getNewObject(T) as T;
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

  @override
  String formattedValue(NsgDataItem item, String locale) {
    var referent = (getReferent(item, allowNull: true));
    if (referent == null) {
      return item[name].toString();
    } else {
      return referent.toString();
    }
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name).toString();
    var valueB = b.getFieldValue(name).toString();
    return valueA.compareTo(valueB);
  }
}
