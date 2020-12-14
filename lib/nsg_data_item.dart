import 'package:nsg_data/dataFields/datafield.dart';
import 'package:nsg_data/dataFields/referenceField.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_fieldlist.dart';
import 'package:nsg_data/nsg_data_provider.dart';
import 'nsg_data_paramList.dart';

class NsgDataItem {
  static const String ZERO_GUID = '00000000-0000-0000-0000-000000000000';
  List<String> loadReferenceDefault;

  ///Get API path for request Items
  String get apiRequestItems {
    throw Exception('api Request Items is not overrided');
  }

  String get apiPostItems => apiRequestItems + '/Post';

  void fromJson(Map<String, dynamic> json) {
    json.forEach((name, jsonValue) {
      if (fieldList.fields.containsKey(name)) {
        setFieldValue(name, fieldList.fields[name].convertJsonValue(jsonValue));
      }
    });
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    fieldList.fields.forEach((name, value) {
      map[name] = value.convertToJson(getFieldValue(name));
    });
    return map;
  }

  NsgDataItem getNewObject() {
    throw Exception('getNewObject for type {runtimeType} is not defined');
  }

  void initialize() {
    throw Exception('initialize for type {runtimeType} is not defined');
  }

  NsgFieldList get fieldList => NsgDataClient.client.getFieldList(this);
  NsgParamList get paramList => NsgDataClient.client.getParamList(this);
  final NsgFieldValues fieldValues = NsgFieldValues();

  void addfield(NsgDataField field, {bool primaryKey = false}) {
    var name = field.name;
    assert(!fieldList.fields.containsKey(name));
    fieldList.fields[name] = field;
    if (primaryKey) {
      assert(primaryKeyField == null || primaryKeyField == '');
      primaryKeyField = name;
    }
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
    if (value is NsgDataItem) {
      value = (value as NsgDataItem)
          .getFieldValue((value as NsgDataItem).primaryKeyField);
    }
    fieldValues.fields[name] = value;
  }

  static const String _PARAM_REMOTE_PROVIDER = 'RemoteProvider';
  NsgDataProvider get remoteProvider {
    if (paramList.params.containsKey(_PARAM_REMOTE_PROVIDER)) {
      return paramList.params[_PARAM_REMOTE_PROVIDER] as NsgDataProvider;
    } else {
      return null;
    }
  }

  set remoteProvider(NsgDataProvider value) =>
      paramList.params[_PARAM_REMOTE_PROVIDER] = value;

  T getReferent<T extends NsgDataItem>(String name) {
    assert(fieldList.fields.containsKey(name));
    var field = fieldList.fields[name];
    assert(field is NsgDataReferenceField);
    return (field as NsgDataReferenceField).getReferent(this) as T;
  }

  Future<T> getReferentAsync<T extends NsgDataItem>(String name) async {
    assert(fieldValues.fields.containsKey(name));
    var field = fieldList.fields[name];
    assert(field is NsgDataReferenceField);
    var dataItem =
        await ((field as NsgDataReferenceField).getReferentAsync(this));
    return dataItem as T;
  }

  static const String _PRIMARY_KEY_FIELD = 'PrimaryKeyField';
  String get primaryKeyField {
    if (paramList.params.containsKey(_PRIMARY_KEY_FIELD)) {
      return paramList.params[_PRIMARY_KEY_FIELD].toString();
    } else {
      return '';
    }
  }

  set primaryKeyField(String value) =>
      paramList.params[_PRIMARY_KEY_FIELD] = value;

  List<String> getAllReferenceFields() {
    var list = <String>[];
    fieldValues.fields.keys.forEach((name) {
      var field = fieldList.fields[name];
      if (field is NsgDataReferenceField) {
        list.add(name);
      }
    });

    return list;
  }

  bool get isEmpty => getFieldValue(primaryKeyField).toString() == ZERO_GUID;
  bool get isNotEmpty => !isEmpty;
  @override
  bool operator ==(Object other) => other is NsgDataItem && equal(other);
  bool equal(NsgDataItem other) {
    if (other.runtimeType == runtimeType) {
      if (primaryKeyField == '') return hashCode == other.hashCode;
      return (getFieldValue(primaryKeyField) ==
          other.getFieldValue(primaryKeyField));
    }
    return false;
  }

  @override
  int get hashCode {
    if (primaryKeyField == '') return super.hashCode;
    return getFieldValue(primaryKeyField).hashCode;
  }

  Future post() async {
    var p = NsgDataPost(dataItemType: runtimeType);
    p.itemsToPost = <NsgDataItem>[this];
    var newItem = await p.postItem();
    if (newItem != null) {
      copyFieldValues(newItem);
    }
  }

  void copyFieldValues(NsgDataItem newItem) {
    fieldValues.fields.forEach((key, value) {
      setFieldValue(key, newItem.getFieldValue(key));
    });
  }
}
