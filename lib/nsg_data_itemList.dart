// ignore_for_file: file_names

import 'package:nsg_data/nsg_data_item.dart';

class NsgItemList {
  final Map<String, NsgDataCashedItem> items = <String, NsgDataCashedItem>{};

  ///Положить объект в кэш.
  ///
  ///Если объект с таким id уже есть, новые значения **вливаются** в него, а не
  ///заменяют запись целиком. Замена была опасна при сужении запросов: экран,
  ///прочитавший объект узко, вытеснял из кэша полную версию, и ломался не он, а
  ///соседний экран, который резолвил через кэш ссылку и не находил поля (#1394).
  ///
  ///Слияние даёт нужное свойство: сужение **не может** сделать кэшированный
  ///объект беднее, чем он был. Непрочитанные поля источника при этом не
  ///копируются (см. [NsgDataItem.copyFieldValues]), так что свежая узкая версия
  ///не затирает то, что уже знали.
  ///
  ///Экземпляр сохраняется прежний — на него уже могут ссылаться открытые экраны,
  ///и подмена объекта рвала бы им данные.
  void add({required NsgDataItem item, DateTime? time, String? tag = ''}) {
    if (item.primaryKeyField == '') return;
    var id = item.getFieldValue(item.primaryKeyField).toString();
    if (id == '') return;
    time ??= DateTime.now();
    var existing = items[id]?.dataItem;
    if (existing != null && !identical(existing, item) && existing.runtimeType == item.runtimeType) {
      existing.copyFieldValues(item);
      items[id] = NsgDataCashedItem(dataItem: existing, loadedTime: time, tag: tag);
      return;
    }
    items[id] = NsgDataCashedItem(dataItem: item, loadedTime: time, tag: tag);
  }

  NsgDataCashedItem? getItem(String id) {
    if (items.containsKey(id)) {
      return items[id];
    } else {
      return null;
    }
  }
}

class NsgDataCashedItem {
  final NsgDataItem? dataItem;
  final DateTime? loadedTime;
  final String? tag;

  NsgDataCashedItem({this.dataItem, this.loadedTime, this.tag = ''});
}
