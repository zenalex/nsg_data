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
  List<T> get rows {
    var allRows = owner.getFieldValue(fieldName);
    return (allRows as List).cast();
  }

  int get length => rows.length;

  ///Добавить новую строку в табличную часть
  ///dataItem - объект, в поле которого добавляем значение
  ///row - добавляемое значение
  void addRow(T row) {
    List<T>? untypedRows = owner.getFieldValue(fieldName, allowNullValue: true);
    untypedRows ??= [];
    var allRows = untypedRows.cast<T>();
    if (row.isEmpty) {
      row.setFieldValue(row.primaryKeyField, Guid.newGuid());
    }
    if (row.ownerId.isNotEmpty) {
      row.ownerId = owner.id;
    }
    allRows.add(row);
    owner.setFieldValue(fieldName, allRows);
  }

  ///Вставить новую строку в табличную часть
  ///dataItem - объект, в поле которого добавляем значение
  ///index - место вставки
  ///row - добавляемое значение
  void insertRow(int index, T row) {
    List<T>? untypedRows = owner.getFieldValue(fieldName, allowNullValue: true);
    untypedRows ??= [];
    var allRows = untypedRows.cast<T>();
    if (row.isEmpty) {
      row.setFieldValue(row.primaryKeyField, Guid.newGuid());
    }
    if (row.ownerId.isNotEmpty) {
      row.ownerId = owner.id;
    }
    allRows.insert(index, row);
    owner.setFieldValue(fieldName, allRows);
  }

  ///Удалить строку тз табличной части
  ///dataItem - объект, в поле которого добавляем значение
  ///row - удаляемая строка
  bool removeRow(T row) {
    var allRows = ((owner.getFieldValue(fieldName, allowNullValue: true) as List).cast<List<T>?>());
    return allRows.remove(row);
  }

  ///Удалить все строки из табличной чатси
  void clear() {
    var allRows = (owner.getFieldValue(fieldName, allowNullValue: true) as List<T>?) ?? <T>[];
    allRows.clear();
  }
}
