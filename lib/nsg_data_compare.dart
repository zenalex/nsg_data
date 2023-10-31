import 'dart:convert';
import 'nsg_data.dart';

enum NsgLogicalOperator { and, or }

class NsgCompare {
  /// логический оператор
  var logicalOperator = NsgLogicalOperator.and;
  // параметры условий
  List<NsgCompareParam> paramList = [];

  /// Проверка наличия в фильтре хотя бы одного условия
  bool get isEmpty {
    var res = true;
    for (var param in paramList) {
      if (param.parameterValue is NsgCompare) {
        res = res && (param.parameterValue as NsgCompare).isEmpty;
      } else {
        res = false;
      }
    }
    return res;
  }

  bool get isNotEmpty => !isEmpty;

  int get length => paramList.length;

  /// Возвращаем количество параметров с учетов всех вложенных параметров
  int get lengthAll {
    int i = 0;
    for (var param in paramList) {
      {
        if (param.parameterValue is NsgCompare) {
          i += (param.parameterValue as NsgCompare).lengthAll;
        } else {
          i++;
        }
      }
    }
    return i;
  }

  void add({required String name, required dynamic value, NsgComparisonOperator comparisonOperator = NsgComparisonOperator.equal}) {
    bool isDataItem = value is NsgDataItem;
    bool isTypeOperator = (comparisonOperator == NsgComparisonOperator.typeEqual || comparisonOperator == NsgComparisonOperator.typeNotEqual);
    assert(isTypeOperator ? (isDataItem) : true, 'Не поддерживаемый тип');
    paramList.add(NsgCompareParam(parameterName: name, parameterValue: value, comparisonOperator: comparisonOperator));
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
    for (var param in paramList) {
      list.add(param.toJson());
    }
    map['LogicalOperator'] = logicalOperator == NsgLogicalOperator.and ? 1 : 2;
    map['ParamList'] = list;
    return map;
  }

  void clear() {
    paramList.clear();
  }

  bool isValid(NsgDataItem item) {
    if (isEmpty) return true;
    var r = logicalOperator == NsgLogicalOperator.and;
    for (var param in paramList) {
      if (logicalOperator == NsgLogicalOperator.and) {
        r &= param.isValid(item);
      } else {
        r |= param.isValid(item);
      }
    }
    return r;
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
      if (comparisonOperator == NsgComparisonOperator.typeEqual || comparisonOperator == NsgComparisonOperator.typeNotEqual) {
        map['Value'] = (parameterValue as NsgDataItem).typeName;
      } else {
        map["Value"] = (parameterValue as NsgDataItem).id;
      }
    } else if (parameterValue is List && (parameterValue as List).isNotEmpty && (parameterValue as List).first is NsgDataItem) {
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

  bool isValid(NsgDataItem item) {
    if (parameterValue is NsgCompare) {
      return (parameterValue as NsgCompare).isValid(item);
    }

    var value = item.getFieldValueByFullPath(parameterName);
    if (value == null) {
      return false;
    }
    if (comparisonOperator == NsgComparisonOperator.beginWith) {
      return (value.toString().toLowerCase().startsWith(parameterValue.toString().toLowerCase()));
    } else if (comparisonOperator == NsgComparisonOperator.contain) {
      return (value.toString().toLowerCase().contains(parameterValue.toString().toLowerCase()));
    } else if (comparisonOperator == NsgComparisonOperator.containWords) {
      var words = parameterValue.toString().split(' ');
      value = value.toString().toLowerCase();
      return words.every(((e) => value.contains(e.toLowerCase())));
    } else if (comparisonOperator == NsgComparisonOperator.endWith) {
      return (value.toString().toLowerCase().endsWith(parameterValue.toString().toLowerCase()));
    } else if (comparisonOperator == NsgComparisonOperator.equal) {
      var pv = parameterValue;
      if (parameterValue is NsgDataItem) {
        pv = (parameterValue as NsgDataItem).id;
      }
      return (value == pv);
    } else if (comparisonOperator == NsgComparisonOperator.notEqual) {
      var pv = parameterValue;
      if (parameterValue is NsgDataItem) {
        pv = (parameterValue as NsgDataItem).id;
      }
      return (value != pv);
    } else if (comparisonOperator == NsgComparisonOperator.inList) {
      return ((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.typeEqual) {
      return value.runtimeType == item.runtimeType;
    } else if (comparisonOperator == NsgComparisonOperator.greaterOrEqual) {
      var pv = parameterValue;
      return (value >= pv);
    } else if (comparisonOperator == NsgComparisonOperator.lessOrEqual) {
      var pv = parameterValue;
      return (value <= pv);
    } else if (comparisonOperator == NsgComparisonOperator.greater) {
      var pv = parameterValue;
      return (value > pv);
    } else if (comparisonOperator == NsgComparisonOperator.less) {
      var pv = parameterValue;
      return (value < pv);
    } else {
      return false;
    }
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
