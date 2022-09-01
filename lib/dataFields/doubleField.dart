import '../nsg_data.dart';

class NsgDataDoubleField extends NsgDataField {
  final int maxDecimalPlaces;

  NsgDataDoubleField(String name, {this.maxDecimalPlaces = 2}) : super(name);

  @override
  dynamic convertToJson(dynamic jsonValue) {
    if (jsonValue is int) return jsonValue.toDouble();
    if (jsonValue is String) return double.parse(jsonValue);
    return jsonValue as double;
  }

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    if (jsonValue is int) return jsonValue.toDouble();
    if (jsonValue is String) return double.parse(jsonValue);
    return jsonValue as double;
  }

  @override
  dynamic get defaultValue => 0.0;

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value == null) {
      fieldValues.fields[name] = 0;
      return;
    }
    if (value is String) {
      var d = (double.tryParse(value) ?? 0.0).nsgRoundToDouble(maxDecimalPlaces);
      fieldValues.fields[name] = d;
    } else if (value is double) {
      value = value.nsgRoundToDouble(maxDecimalPlaces);
      fieldValues.fields[name] = value;
    } else if (value is int) {
      fieldValues.fields[name] = value.toDouble();
    } else {
      fieldValues.fields[name] = 0.0;
    }
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name) as double;
    var valueB = b.getFieldValue(name) as double;
    return valueA.compareTo(valueB);
  }
}
