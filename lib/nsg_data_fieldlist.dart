import 'nsg_data.dart';

class NsgFieldList {
  ///Массив полей объекта
  final Map<String, NsgDataField> fields = <String, NsgDataField>{};
}

class NsgFieldValues {
  ///Значения полей объекта
  final Map<String, dynamic> fields = <String, dynamic>{};
  final List<String> emptyFields = <String>[];

  ///Табличные части, в которые реально клали содержимое — с сервера или руками.
  ///
  ///По одному лишь наличию ключа в [fields] это не определить: чтение незагруженной
  ///таблицы материализует туда пустой список (и убрать это нельзя — на такой список
  ///опирается прямое добавление строк через `allRows`). Без отдельного признака
  ///«не загружена» неотличима от «загружена и пуста», а значит слияние объектов
  ///обнуляло бы таблицу, которую просто ни разу не читали (#1394).
  final Set<String> loadedTables = <String>{};

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
