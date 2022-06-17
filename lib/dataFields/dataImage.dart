import 'dart:convert';

import '../nsg_data.dart';

///Поле - картика. С сервера
class NsgDataImageField extends NsgDataField {
  NsgDataImageField(String name) : super(name);
  @override
  dynamic get defaultValue => <int>[];

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return base64Decode(jsonValue.toString());
  }

  @override
  dynamic convertToJson(dynamic jsonValue) {
    return base64Encode(jsonValue);
  }

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is String) {
      fieldValues.fields[name] = base64Decode(value.toString());
    } else if (value is List<int>) {
      fieldValues.fields[name] = value;
    }
  }
}
