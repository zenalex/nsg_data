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

  ///При задании этого списка другие поля не будут прочитаны вообще
  ///Имеет смысл использовать только при тонкой оптимизации объема передаваемых данных
  String? fieldsToRead;

  ///Список полей для группировки данных
  ///Имеет смысл при запросе данных по регистру
  List<String>? groupBy;

  ///Возвращать помеченные на удаление
  bool showDeletedObjects;

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
    if (groupBy != null) filter['GroupBy'] = groupBy;
    if (compare.isNotEmpty) filter['Compare'] = compare.toJson();
    filter['ShowDeletedObjects'] = showDeletedObjects.toString();
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

  NsgDataRequestParams({this.top = 0, this.count = 0, this.params, this.sorting, this.referenceList, this.showDeletedObjects = false, NsgCompare? compare}) {
    if (compare != null) {
      _compare = compare;
    }
  }
}
