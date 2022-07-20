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
    paramList.add(new NsgSortingParam(parameterName: name, direction: direction));
  }

  void clear() {
    paramList.clear();
  }

  @override
  String toString() {
    var s = '';
    paramList.forEach((param) {
      if (s.length > 0) s += ',';
      s += param.parameterName + (param.direction == NsgSortingDirection.ascending ? '+' : '-');
    });

    return s;
  }
}

class NsgSortingParam {
  /// Значение
  final String parameterName;

  ///Оператор сравнения
  final NsgSortingDirection direction;

  NsgSortingParam({required this.parameterName, required this.direction}) : super();
}
