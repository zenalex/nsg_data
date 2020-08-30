import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataImageField extends NsgDataField {
  NsgDataImageField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';
}
