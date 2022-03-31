import '../nsg_data.dart';

class NsgDataDateField extends NsgDataField {
  NsgDataDateField(String name) : super(name);
  @override
  dynamic get defaultValue => DateTime(1);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return DateTime.parse(jsonValue.toString());
  }

  @override
  dynamic convertToJson(dynamic jsonValue) {
    return jsonValue.toIso8601String();
    //(jsonValue as DateTime).microsecondsSinceEpoch;
  }

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is String) {
      fieldValues.fields[name] = DateTime.parse(value);
    } else {
      fieldValues.fields[name] = value;
    }
  }
}
