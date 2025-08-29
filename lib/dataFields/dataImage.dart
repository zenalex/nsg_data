// ignore_for_file: file_names

import 'dart:convert';
import 'dart:typed_data';

import '../nsg_data.dart';

///Поле - картика. С сервера
class NsgDataImageField extends NsgDataField {
  NsgDataImageField(super.name);
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
    var valueA = a.getFieldValue(name) as Uint8List;
    var valueB = a.getFieldValue(name) as Uint8List;
    return valueA.hashCode.compareTo(valueB.hashCode);
  }
}
