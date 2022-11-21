import 'package:nsg_data/dataFields/datafield.dart';

import '../nsg_data_item.dart';

class NsgDataBoolField extends NsgDataField {
  NsgDataBoolField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return (jsonValue.toString().toLowerCase() == 'true' || jsonValue.toString().toLowerCase() == '1');
  }

  @override
  dynamic get defaultValue => false;

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name) as bool;
    var valueB = b.getFieldValue(name) as bool;
    return valueA == valueB
        ? 0
        : valueA && !valueB
            ? 1
            : -1;
  }
}
