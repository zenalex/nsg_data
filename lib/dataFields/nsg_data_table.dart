import 'package:nsg_data/helpers/nsg_data_guid.dart';

import '../nsg_data.dart';

class NsgDataTable<T extends NsgDataItem> {
  NsgDataTable({required this.owner, required this.fieldName}) : super() {
    assert(owner.getField(fieldName) is NsgDataReferenceListField);
    dataItemType = (owner.getField(fieldName) as NsgDataReferenceListField).referentElementType;
  }

  final NsgDataItem owner;
  final String fieldName;

  Type dataItemType = NsgDataItem;

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
  List<T> get rows => owner.getFieldValue(fieldName) as List<T>;
  int get length => rows.length;

  ///Добавить новую строку в табличную часть
  ///dataItem - объект, в поле которого добавляем значение
  ///row - добавляемое значение
  void addRow(T row) {
    var allRows = (owner.getFieldValue(fieldName, allowNullValue: true) as List<T>?) ?? <T>[];
    if (row.isEmpty) {
      row.setFieldValue(row.primaryKeyField, Guid.newGuid());
    }
    if (row.ownerId.isNotEmpty) {
      row.setFieldValue(row.ownerId, owner.id);
    }
    allRows.add(row);
    owner.setFieldValue(fieldName, allRows);
  }
}
