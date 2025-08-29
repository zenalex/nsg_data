// ignore_for_file: file_names

import '../nsg_data.dart';

class NsgDataStringField extends NsgDataField {
  final int maxLength;

  NsgDataStringField(super.name, {this.maxLength = 0});

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name).toString();
    var valueB = b.getFieldValue(name).toString();
    return valueA.compareTo(valueB);
  }
}
