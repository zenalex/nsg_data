import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataBoolField extends NsgDataField {
  NsgDataBoolField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return (jsonValue.toString().toLowerCase() == 'true' ||
        jsonValue.toString().toLowerCase() == '1');
  }

  @override
  dynamic get defaultValue => false;
}
