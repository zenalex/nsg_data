import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataDoubleField extends NsgDataField {
  NsgDataDoubleField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return double.parse(jsonValue.toString());
  }

  @override
  dynamic get defaultValue => 0;
}
