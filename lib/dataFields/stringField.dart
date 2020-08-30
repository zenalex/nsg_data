import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataStringField extends NsgDataField {
  NsgDataStringField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';
}
