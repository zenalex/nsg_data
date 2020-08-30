import 'package:nsg_data/dataFields/datafield.dart';

class NsgDataReferenceField extends NsgDataField {
  NsgDataReferenceField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  //NsgDataItem get reference{

  //}
}
