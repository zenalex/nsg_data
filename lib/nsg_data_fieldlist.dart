import 'nsg_data.dart';

class NsgFieldList {
  ///Массив полей объекта
  final Map<String, NsgDataField> fields = <String, NsgDataField>{};
}

class NsgFieldValues {
  ///Значения полей объекта
  final Map<String, dynamic> fields = <String, dynamic>{};
  final List<String> emptyFields = <String>[];

  ///Установить значение поля объекта
  setValue(NsgDataItem obj, String name, dynamic value) {
    var field = NsgDataClient.client.getFieldList(obj.runtimeType).fields[name];
    assert(field != null);
    field!.setValue(this, value);
  }

  ///Пометить поле пустым
  setEmpty(NsgDataItem obj, String name) {
    var field = NsgDataClient.client.getFieldList(obj.runtimeType).fields[name];
    assert(field != null);
    field!.setEmpty(this);
  }
}
