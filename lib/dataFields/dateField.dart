// ignore_for_file: file_names

import 'package:jiffy/jiffy.dart';

import '../nsg_data.dart';

class NsgDataDateField extends NsgDataField {
  NsgDataDateField(String name, {this.useDate = true, this.useTime = true}) : super(name);
  @override
  dynamic get defaultValue => DateTime(1);

  bool useDate = true;
  bool useTime = true;

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    if (useDate == useTime) return DateTime.parse(jsonValue.toString()).toLocal();
    return DateTime.parse(jsonValue.toString());
  }

  @override
  dynamic convertToJson(dynamic jsonValue) {
    if (useDate == useTime) return (jsonValue as DateTime).toUtc().toIso8601String();
    return (jsonValue as DateTime).toIso8601String();
  }

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is String) {
      if (useDate == useTime) {
        fieldValues.fields[name] = DateTime.parse(value).toLocal();
      } else {
        if (value.endsWith('Z') || value.endsWith('z')) {
          fieldValues.fields[name] = DateTime.parse(value);
        } else {
          fieldValues.fields[name] = DateTime.parse(value + 'Z');
        }
      }
    } else {
      fieldValues.fields[name] = value;
    }
  }

  @override
  String formattedValue(NsgDataItem item, String locale) {
    return NsgDateFormat.dateFormat(item[name], locale: locale);
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
