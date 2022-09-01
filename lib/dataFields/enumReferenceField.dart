import 'package:nsg_data/nsg_data.dart';

class NsgDataEnumReferenceField<T extends NsgEnum> extends NsgDataBaseReferenceField {
  NsgDataEnumReferenceField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => 0;

  Type get referentType => T;

  T? getReferent(NsgDataItem dataItem, {bool useCache = true}) {
    int? v = dataItem.fieldValues.fields[name];
    if (v == null) {
      v = defaultValue;
    }
    return (NsgEnum.fromValue(referentType, v!) as T);
  }

  Future<NsgDataItem> getReferentAsync(NsgDataItem dataItem, {bool useCache = true}) async {
    return getReferent(dataItem) as NsgDataItem;
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name) as int;
    var valueB = b.getFieldValue(name) as int;
    return valueA.compareTo(valueB);
  }
}
