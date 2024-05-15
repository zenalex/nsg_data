// ignore_for_file: file_names

import 'package:jiffy/jiffy.dart';

import '../nsg_data.dart';

class NsgDataDateField extends NsgDataField {
  NsgDataDateField(String name) : super(name);
  @override
  dynamic get defaultValue => DateTime(1);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return DateTime.parse(jsonValue.toString()).toLocal();
  }

  @override
  dynamic convertToJson(dynamic jsonValue) {
    return (jsonValue as DateTime).toUtc().toIso8601String();
  }

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is String) {
      fieldValues.fields[name] = DateTime.parse(value).toLocal();
    } else {
      fieldValues.fields[name] = value;
    }
  }

  @override
  String formattedValue(NsgDataItem item) {
    return NsgDateFormat.dateFormat(item[name]);
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = Jiffy.parseFromDateTime(a.getFieldValue(name) as DateTime);
    var valueB = Jiffy.parseFromDateTime(b.getFieldValue(name) as DateTime);
    return valueA.isAfter(valueB)
        ? 1
        : valueB.isAfter(valueA)
            ? -1
            : 0;
  }
}
