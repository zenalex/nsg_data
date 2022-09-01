import '../nsg_data.dart';

class NsgDataIntField extends NsgDataField {
  NsgDataIntField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue as int;
  }

  @override
  dynamic get defaultValue => 0;

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value == null) {
      fieldValues.fields[name] = 0;
      return;
    }
    if (value is String) {
      fieldValues.fields[name] = int.tryParse(value) ?? 0;
    } else {
      fieldValues.fields[name] = value;
    }
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name) as int;
    var valueB = b.getFieldValue(name) as int;
    return valueA.compareTo(valueB);
  }
}
