import 'nsg_data.dart';

class NsgFieldList {
  final Map<String, NsgDataField> fields = <String, NsgDataField>{};
}

class NsgFieldValues {
  final Map<String, dynamic> fields = <String, dynamic>{};

  setValue(NsgDataItem obj, String name, dynamic value) {
    var field = NsgDataClient.client.getFieldList(obj.runtimeType).fields[name];
    assert(field != null);
    field!.setValue(this, value);
  }
}
