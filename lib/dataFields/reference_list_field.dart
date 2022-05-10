import '../nsg_data.dart';

class NsgDataReferenceListField<T extends NsgDataItem> extends NsgDataBaseReferenceField {
  NsgDataReferenceListField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => <T>[];

  Type get referentType => List<T>;

  @override
  Type get referentElementType => T;

  List<T>? getReferent(NsgDataItem dataItem, {bool useCache = true}) {
    return dataItem.getFieldValue(name);
  }

  Future<List<T>> getReferentAsync(NsgDataItem dataItem, {bool useCache = true}) async {
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
    if (value is List<NsgDataItem>) {
      fieldValues.fields[name] = value;
    } else if (value is List) {
      fieldValues.fields[name] = fromJsonList(value);
    } else {
      fieldValues.fields[name] = defaultValue;
    }
  }

  List<T> fromJsonList(List<dynamic> maps) {
    var items = <T>[];
    maps.forEach((m) {
      var elem = NsgDataClient.client.getNewObject(referentElementType);
      if (m is Map<String, dynamic>) {
        elem.fromJson(m);
      } else if (m.runtimeType == referentElementType) {
        elem.copyFieldValues(m);
      } else {
        throw Exception("Exception ReferenceListField 65. Unknown value type");
      }
      items.add(elem as T);
    });
    return items;
  }

  ///Добавить новую строку в табличную часть
  ///dataItem - объект, в поле которого добавляем значение
  ///row - добавляемое значение
  void addRow(NsgDataItem dataItem, T row) {
    var allRows = (dataItem.getFieldValue(name, allowNullValue: true) as List<T>?) ?? <T>[];
    allRows.add(row);
    setValue(dataItem.fieldValues, allRows);
  }
}
