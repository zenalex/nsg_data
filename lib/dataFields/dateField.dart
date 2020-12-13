import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataDateField extends NsgDataField {
  NsgDataDateField(String name) : super(name);
  @override
  dynamic get defaultValue => DateTime(1970);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return DateTime.fromMillisecondsSinceEpoch(int.parse(jsonValue.toString()),
        isUtc: true);
  }

  @override
  dynamic convertToJson(dynamic jsonValue) {
    return (jsonValue as DateTime).microsecondsSinceEpoch;
  }
}
