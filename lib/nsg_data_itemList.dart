import 'package:nsg_data/nsg_data_item.dart';

class NsgItemList {
  final Map<String, NsgDataCashedItem> items = <String, NsgDataCashedItem>{};

  void add({required NsgDataItem item, DateTime? time, String? tag = ''}) {
    if (item.primaryKeyField == '') return;
    var id = item.getFieldValue(item.primaryKeyField).toString();
    if (id == '') return;
    time ??= DateTime.now();
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
