import 'dart:convert';
import 'dart:typed_data';

import '../nsg_data.dart';

///Поле - картика. С сервера
class NsgDataBinaryField extends NsgDataField {
  NsgDataBinaryField(String name) : super(name);
  @override
  dynamic get defaultValue => Uint8List(0);

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
    } else if (value is Uint8List) {
      fieldValues.fields[name] = value;
    } else if (value is List<int>) {
      fieldValues.fields[name] = Uint8List.fromList(value);
    }
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    throw Exception('compareTo is not realized for binary field');
  }
}
