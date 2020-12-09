import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataDoubleField extends NsgDataField {
  NsgDataDoubleField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    if (jsonValue is int) return jsonValue.toDouble();
    return jsonValue as double;
  }

  @override
  dynamic get defaultValue => 0;
}
