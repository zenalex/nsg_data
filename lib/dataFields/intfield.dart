import '../nsg_data.dart';

class NsgDataIntField extends NsgDataField {
  NsgDataIntField(String name) : super(name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue as int;
  }

  @override
  dynamic get defaultValue => 0;

  @override
  void setValue(NsgFieldValues fieldValues, dynamic value) {
    if (value is String) {
      fieldValues.fields[name] = int.tryParse(value);
    } else {
      fieldValues.fields[name] = value;
    }
  }
}
