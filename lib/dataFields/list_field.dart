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

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name) as List;
    var valueB = b.getFieldValue(name) as List;
    return valueA.hashCode.compareTo(valueB.hashCode);
  }
}
