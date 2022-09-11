import '../nsg_data.dart';

class NsgDataStringField extends NsgDataField {
  final int maxLength;

  NsgDataStringField(String name, {this.maxLength = 0}) : super(name);

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
