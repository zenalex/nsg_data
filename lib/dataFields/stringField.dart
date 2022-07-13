import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataStringField extends NsgDataField {
  final int maxLength;

  NsgDataStringField(String name, {this.maxLength = 0}) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';
}
