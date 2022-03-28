import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataDoubleField extends NsgDataField {
  final int maxDecimalPlaces;

  NsgDataDoubleField(String name, {this.maxDecimalPlaces = 2}) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    if (jsonValue is int) return jsonValue.toDouble();
    return jsonValue as double;
  }

  @override
  dynamic get defaultValue => 0.0;
}
