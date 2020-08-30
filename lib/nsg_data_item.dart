import 'package:nsg_data/dataFields/datafield.dart';
import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_fieldlist.dart';

class NsgDataItem {
  ///Get API path for request Items
  String get apiRequestItems {
    throw Exception('api Request Items is not overrided');
  }

  NsgDataItem();

  void fromJson(Map<String, dynamic> json) {
    json.forEach((name, jsonValue) {
      if (fieldList.fields.containsKey(name)) {
        setFieldValue(name, fieldList.fields[name].convertJsonValue(jsonValue));
      }
    });
  }

  NsgDataItem getNewObject() {
    throw Exception('getNewObject for type {runtimeType} is not defined');
  }

  void initialize() {
    throw Exception('initialize for type {runtimeType} is not defined');
  }

  NsgFieldList get fieldList => NsgDataClient.client.getFieldList(this);
  final NsgFieldValues fieldValues = NsgFieldValues();

  void addfield(NsgDataField field) {
    var name = field.name;
    assert(!fieldList.fields.containsKey(name));
    fieldList.fields[name] = field;
  }

  dynamic getFieldValue(String name) {
    if (fieldValues.fields.containsKey(name)) {
      return fieldValues.fields[name];
    } else {
      return fieldList.fields[name].defaultValue;
    }
  }

  void setFieldValue(String name, dynamic value) {
    assert(fieldList.fields.containsKey(name));
    fieldValues.fields[name] = value;
  }
}
