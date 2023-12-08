import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';

enum NsgSortingDirection { ascending, descending }

class NsgSorting {
  // параметры условий
  List<NsgSortingParam> paramList = [];

  /// Проверка наличия в фильтре хотя бы одного условия
  bool get isEmpty {
    return paramList.isEmpty;
  }

  /// Проверка наличия в фильтре хотя бы одного условия
  bool get isNotEmpty {
    return paramList.isNotEmpty;
  }

  int get length => paramList.length;

  void add({required String name, required NsgSortingDirection direction}) {
    paramList.add(NsgSortingParam(parameterName: name, direction: direction));
  }

  void clear() {
    paramList.clear();
  }

  @override
  String toString() {
    var s = '';
    for (var param in paramList) {
      if (s.isNotEmpty) s += ',';
      s += param.parameterName + (param.direction == NsgSortingDirection.ascending ? '+' : '-');
    }

    return s;
  }

  ///Добавить параметры сортировки из строки. Параметры в строке разделяются запятыми без пробелов
  ///Могут содержать имя поля (обязательно) и направление сортировки (опционально)
  ///Если направление сортировки не задано, она будет по возрастанию
  ///Например, ИмяПоля1-,ИмяПоля2,ИмяПоля3+
  void addStringParams(String sortingString) {
    for (var stringParam in sortingString.split(',')) {
      var paramDirection = NsgSortingDirection.ascending;
      if (stringParam.isEmpty) continue;
      var lastChar = stringParam[stringParam.length - 1];
      if (lastChar == '+' || lastChar == '-') {
        stringParam.removeLast();
        if (lastChar == '-') {
          paramDirection = NsgSortingDirection.descending;
        }
      }
      add(name: stringParam, direction: paramDirection);
    }
  }
}

class NsgSortingParam {
  /// Значение
  final String parameterName;

  ///Оператор сравнения
  final NsgSortingDirection direction;

  NsgSortingParam({required this.parameterName, required this.direction}) : super();
}
