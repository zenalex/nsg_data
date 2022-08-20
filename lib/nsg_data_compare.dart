import 'dart:convert';

import 'package:nsg_data/nsg_comparison_operator.dart';

import 'nsg_data.dart';

enum NsgLogicalOperator { And, Or }

class NsgCompare {
  /// логический оператор
  var logicalOperator = NsgLogicalOperator.And;
  // параметры условий
  List<NsgCompareParam> paramList = [];

  /// Проверка наличия в фильтре хотя бы одного условия
  bool get isEmpty {
    var res = true;
    this.paramList.forEach((param) {
      if (param.parameterValue is NsgCompare) {
        res = res && (param.parameterValue as NsgCompare).isEmpty;
      } else {
        res = false;
      }
    });
    return res;
  }

  bool get isNotEmpty => !isEmpty;

  int get length => paramList.length;

  /// Возвращаем количество параметров с учетов всех вложенных параметров
  int get lengthAll {
    int i = 0;
    paramList.forEach((param) => {
          if (param.parameterValue is NsgCompare) {i += (param.parameterValue as NsgCompare).lengthAll} else {i++}
        });
    return i;
  }

  void add({required String name, required dynamic value, NsgComparisonOperator comparisonOperator = NsgComparisonOperator.equal}) {
    paramList.add(new NsgCompareParam(parameterName: name, parameterValue: value, comparisonOperator: comparisonOperator));
  }

  // void fromJson(Map<String, dynamic> json) {
  //   json.forEach((name, jsonValue) {
  //     if (fieldList.fields.containsKey(name)) {
  //       setFieldValue(name, jsonValue);
  //     }
  //   });
  // }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    var list = <Map<String, dynamic>>[];
    paramList.forEach((param) {
      list.add(param.toJson());
    });
    map['LogicalOperator'] = logicalOperator == NsgLogicalOperator.And ? 1 : 2;
    map['ParamList'] = list;
    return map;
  }

  void clear() {
    paramList.clear();
  }
}

class NsgCompareParam {
  /// Значение
  final String parameterName;

  ///Оператор сравнения
  final NsgComparisonOperator comparisonOperator;

  /// Значение
  final dynamic parameterValue;

  NsgCompareParam({required this.parameterName, required this.parameterValue, this.comparisonOperator = NsgComparisonOperator.equal}) : super();
  //   {
  // if (parameterValue is NsgDataItem) {
  //   parameterValue =
  //       parameterValue[parameterValue.primaryKeyField];
  // }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map["Name"] = parameterName;
    map["ComparisonOperator"] = comparisonOperator.value;
    if (parameterValue is DateTime) {
      map["Value"] = (parameterValue as DateTime).toIso8601String();
    } else if (parameterValue is NsgEnum) {
      map["Value"] = (parameterValue as NsgEnum).value;
    } else if (parameterValue is NsgDataItem) {
      map["Value"] = (parameterValue as NsgDataItem).id;
    } else if (parameterValue is List && (parameterValue as List).length > 0 && (parameterValue as List).first is NsgDataItem) {
      var idList = <String>[];
      for (NsgDataItem e in parameterValue as List) {
        idList.add(e.id);
      }
      map["Value"] = idList;
    } else if (parameterValue is NsgCompare) {
      //map["ComparisonOperator"] = NsgComparisonOperator.compare;
      map["Value"] = (parameterValue as NsgCompare).toJson();
    } else {
      map["Value"] = parameterValue;
    }
    return map;
  }

  dynamic convertToJson(parameterValue) {
    if (parameterValue is NsgCompare) {
      return parameterValue.toJson();
    }
    return jsonEncode(parameterValue);
  }
}

// String get type {
//   RegExp guidRegExp = RegExp(
//       r"[{(]?[0-9A-Fa-f]{8}[-]?(?:[0-9A-Fa-f]{4}[-]?){3}[0-9A-Fa-f]{12}[)}]?$");
//   if (guidRegExp.hasMatch(parameterValue)) {
//     return 'System.Guid';
//   }
//   if (parameterValue is double) {
//     return 'System.Double';
//   }
//   if (parameterValue is int) {
//     return 'System.Int64';
//   }
//   return 'System.String';
// }
