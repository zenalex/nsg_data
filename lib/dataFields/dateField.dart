import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataDateField extends NsgDataField {
  NsgDataDateField(String name) : super(name);
  @override
  dynamic get defaultValue => DateTime(1970);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return DateTime.fromMillisecondsSinceEpoch(int.parse(jsonValue),
        isUtc: true);
  }
}
