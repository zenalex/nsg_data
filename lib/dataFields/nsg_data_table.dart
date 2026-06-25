import '../nsg_data.dart';

class NsgDataTable<T extends NsgDataItem> {
  NsgDataTable({required this.owner, required this.fieldName}) : super() {
    assert(owner.getField(fieldName) is NsgDataReferenceListField);
    dataItemType = (owner.getField(fieldName) as NsgDataReferenceListField).referentElementType;
  }

  final NsgDataItem owner;
  final String fieldName;

  Type dataItemType = NsgDataItem;

  bool get isEmpty => allRows.isEmpty;
  bool get isNotEmpty => allRows.isNotEmpty;

  ///Строки табличной части, за исключением удаленных
  List<T> get rows {
    return (allRows as List).where((e) => e.docState != NsgDataItemDocState.deleted).toList().cast();
  }

  ///Все строки таблицы, включая удаленные
  List<T> get allRows {
    return (owner.getFieldValue(fieldName) as List).cast();
  }

  int get length => rows.length;

  ///Добавить новую строку в табличную часть
  ///dataItem - объект, в поле которого добавляем значение
  ///row - добавляемое значение
  void addRow(T row) {
    var untypedRows = owner.getFieldValue(fieldName, allowNullValue: true);
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

  ///Удалить строку из табличной части
  ///dataItem - объект, в поле которого добавляем значение
  ///row - удаляемая строка
  bool removeRow(T row) {
    if (row.remoteProvider.newTableLogic && row.docState == NsgDataItemDocState.saved) {
      row.docState = NsgDataItemDocState.deleted;
      return true;
    }
    var allRows = ((owner.getFieldValue(fieldName, allowNullValue: true) as List).cast<List<T>?>());
    return allRows.remove(row);
  }

  ///Очистить табличную часть.
  ///Семантика идентична построчному вызову [removeRow] для каждой строки:
  /// - при newTableLogic уже сохранённые строки помечаются docState=deleted
  ///   (остаются в allRows и будут удалены из БД при сохранении владельца);
  /// - новые (несохранённые) строки и режим без newTableLogic — удаляются физически.
  ///Это важно: при newTableLogic простое опустошение списка приводило к тому,
  ///что сервер не получал команды на удаление и старые строки оставались в БД
  ///(в т.ч. при copyFieldValues табличной части).
  void clear() {
    // for (var row in allRows.toList()) {
    //   removeRow(row);
    // }
    allRows.clear();
  }
}
