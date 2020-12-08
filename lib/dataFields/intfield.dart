import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataIntField extends NsgDataField {
  NsgDataIntField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue as int;
  }

  @override
  dynamic get defaultValue => 0;
}
