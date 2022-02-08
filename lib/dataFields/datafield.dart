import '../nsg_data.dart';

class NsgDataField {
  final String name;

  NsgDataField(this.name);
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  dynamic convertToJson(dynamic jsonValue) {
    return jsonValue;
  }

  dynamic get defaultValue => null;

  void setValue(NsgFieldValues fieldValues, dynamic value) {
    fieldValues.fields[name] = value;
  }
}
