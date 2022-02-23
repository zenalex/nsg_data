import 'package:nsg_data/nsg_data.dart';

class NsgDataEnumReferenceField<T extends NsgEnum>
    extends NsgDataBaseReferenceField {
  NsgDataEnumReferenceField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => 0;

  Type get referentType => T;

  T? getReferent(NsgDataItem dataItem, {bool useCache = true}) {
    return (NsgEnum.fromValue(
        referentType, int.parse(dataItem.fieldValues.fields[name])) as T);
  }

  Future<T> getReferentAsync(NsgDataItem dataItem,
      {bool useCache = true}) async {
    return getReferent(dataItem) as T;
  }
}
