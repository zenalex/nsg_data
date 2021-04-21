import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataDateField extends NsgDataField {
  NsgDataDateField(String name) : super(name);
  @override
  dynamic get defaultValue => DateTime(1);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return DateTime.parse(jsonValue.toString());
  }

  @override
  dynamic convertToJson(dynamic jsonValue) {
    return jsonValue.toIso8601String();
    //(jsonValue as DateTime).microsecondsSinceEpoch;
  }
}
