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
      fieldValues.fields[name] = double.tryParse(value) ?? 0.0;
    } else {
      fieldValues.fields[name] = value;
    }
  }
}
