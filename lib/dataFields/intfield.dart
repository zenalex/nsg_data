import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataIntField extends NsgDataField {
  NsgDataIntField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return int.parse(jsonValue.toString());
  }

  @override
  dynamic get defaultValue => 0;
}
