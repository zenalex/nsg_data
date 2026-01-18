// ignore_for_file: file_names

import 'dart:convert';

import 'package:nsg_data/nsg_data.dart';

class NsgDataRequestParams {
  int top;

  ///Ограничение на максимальное количество запрашиваемых данных
  ///На стороне сервера задается еще одно ограничение, которое не может быть превышено за счет установки данного параметра
  int count;

  ///Словарь передаваемых параметров
  Map<String, dynamic>? params;

  ///Сортировка. Формат: ИмяПоля+ или ИмяПоля- для указания направления сортировки
  ///Если надо задать сортировку по нескольким полям, следует разделять их запятыми
  String? sorting;

  ///Список ссылочных полей, при нахождении не нулевых ссылок на объекты в этих полях
  ///Вместе со списком основных объектов будут получены все объекты, на которые есть ссылки
  List<String>? referenceList;

  ///При задании этого списка другие поля не будут прочитаны.
  ///Имеет смысл использовать только при тонкой оптимизации объема передаваемых данных
  // @Deprecated('Use [neededFields]')
  String? fieldsToRead;

  ///При задании этого списка другие поля не будут прочитаны
  ///Имеет смысл использовать только при тонкой оптимизации объема передаваемых данных
  ///Замена fieldsToRead
  List<String>? neededFields;

  ///Список полей для группировки данных
  ///Имеет смысл при запросе данных по регистру
  List<String>? groupBy;

  ///Возвращать помеченные на удаление
  bool showDeletedObjects;

  /// Идентификатор транзакции. Имеет смысл при Post-запросах
  String? transactionId;

  /// Идентификатор запроса. Имеет смысл при Post-запросах
  String? requestId;

  NsgCompare _compare = NsgCompare();

  ///Условие на запрашиваемые данные
  NsgCompare get compare => _compare;

  Map<String, dynamic> toJson() {
    var filter = <String, dynamic>{};
    if (top != 0) filter['Top'] = jsonEncode(top); //.toString();
    if (count != 0) filter['Count'] = jsonEncode(count); //.toString();
    if (sorting != null) filter['Sorting'] = jsonEncode(sorting);
    if (referenceList != null) filter['ReadReferences'] = referenceList;
    if (fieldsToRead != null) filter['FieldsToRead'] = fieldsToRead.toString();
    if (neededFields != null) filter['NeededFields'] = neededFields;
    if (groupBy != null) filter['GroupBy'] = groupBy;
    if (compare.isNotEmpty) filter['Compare'] = compare.toJson();
    filter['ShowDeletedObjects'] = showDeletedObjects.toString();
    if (transactionId != null) filter['TransactionId'] = transactionId.toString();
    if (requestId != null) filter['RequestId'] = requestId.toString();
    if (params != null) {
      var paramDict = <String, dynamic>{};
      paramDict.addAll(params!);
      filter['Parameters'] = paramDict;
    }
    return filter;
  }

  ///Заменить действующее условие на новое
  void replaceCompare(NsgCompare newCompare) {
    _compare = newCompare;
  }

  /// Создает глубокую копию объекта NsgDataRequestParams
  NsgDataRequestParams clone() {
    return NsgDataRequestParams(
        top: top,
        count: count,
        params: params != null ? Map<String, dynamic>.from(params!) : null,
        sorting: sorting,
        referenceList: referenceList != null ? List<String>.from(referenceList!) : null,
        showDeletedObjects: showDeletedObjects,
        compare: _compare.clone(),
      )
      ..fieldsToRead = fieldsToRead
      ..neededFields = neededFields != null ? List<String>.from(neededFields!) : null
      ..groupBy = groupBy != null ? List<String>.from(groupBy!) : null
      ..transactionId = transactionId
      ..requestId = requestId;
  }

  NsgDataRequestParams({this.top = 0, this.count = 0, this.params, this.sorting, this.referenceList, this.showDeletedObjects = false, NsgCompare? compare}) {
    if (compare != null) {
      _compare = compare;
    }
  }
}
