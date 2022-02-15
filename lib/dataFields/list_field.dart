import '../nsg_data.dart';

class NsgDataListField<T> extends NsgDataField {
  NsgDataListField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => <T>[];

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is List) {
      fieldValues.fields[name] = value;
    } else {
      fieldValues.fields[name] = defaultValue;
    }
  }
}
