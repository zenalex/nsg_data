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

  @override
  String toString() {
    return _toStringFormatted();
  }

  String _toStringFormatted([int indentLevel = 0]) {
    if (isEmpty) return '()';

    var conditions = <String>[];
    for (var param in paramList) {
      conditions.add(_formatParam(param, indentLevel + 1));
    }

    if (conditions.length == 1) {
      return conditions.first;
    }

    var indent = '  ' * indentLevel;
    var operatorStr = logicalOperator == NsgLogicalOperator.and ? '\n${indent}AND ' : '\n${indent}OR ';
    var result = '(\n${indent}  ${conditions.join(operatorStr)}\n${indent})';

    return result;
  }

  String _formatParam(NsgCompareParam param, int indentLevel) {
    if (param.parameterValue is NsgCompare) {
      // Для вложенных условий типа "compare" не показываем оператор
      if (param.comparisonOperator == NsgComparisonOperator.compare) {
        var nested = (param.parameterValue as NsgCompare)._toStringFormatted(indentLevel);
        return '${param.parameterName} ${nested}';
      } else {
        var operatorStr = param._getOperatorSymbol();
        var nested = (param.parameterValue as NsgCompare)._toStringFormatted(indentLevel);
        return '${param.parameterName} ${operatorStr} ${nested}';
      }
    } else {
      var operatorStr = param._getOperatorSymbol();
      var valueStr = param._getValueString();
      return '${param.parameterName} ${operatorStr} ${valueStr}';
    }
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
      map["Value"] = (parameterValue as DateTime).toUtc().toIso8601String();
    } else if (parameterValue is NsgEnum) {
      map["Value"] = (parameterValue as NsgEnum).value;
    } else if (parameterValue is NsgDataItem) {
      if (comparisonOperator == NsgComparisonOperator.typeEqual || comparisonOperator == NsgComparisonOperator.typeNotEqual) {
        map['Value'] = (parameterValue as NsgDataItem).typeName;
      } else {
        map["Value"] = (parameterValue as NsgDataItem).id;
      }
    } else if (parameterValue is List && (parameterValue as List).isNotEmpty && (parameterValue as List).first is NsgDataItem) {
      if ((parameterValue as List).first is NsgEnum) {
        //Для NsgEnum значение целое, а не guid
        var idList = <int>[];
        for (NsgEnum e in parameterValue as List) {
          idList.add(e.value);
        }
        map["Value"] = idList;
      } else {
        var idList = <String>[];
        for (NsgDataItem e in parameterValue as List) {
          idList.add(e.id);
        }
        map["Value"] = idList;
      }
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
      if (parameterValue is NsgEnum) {
        pv = (parameterValue as NsgEnum).value;
      } else if (parameterValue is NsgDataItem) {
        pv = (parameterValue as NsgDataItem).id;
      }
      return (value == pv);
    } else if (comparisonOperator == NsgComparisonOperator.notEqual) {
      var pv = parameterValue;
      if (parameterValue is NsgEnum) {
        pv = (parameterValue as NsgEnum).value;
      } else if (parameterValue is NsgDataItem) {
        pv = (parameterValue as NsgDataItem).id;
      }
      return (value != pv);
    } else if (comparisonOperator == NsgComparisonOperator.inList) {
      return ((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.typeEqual) {
      return value.runtimeType == item.runtimeType;
    } else if (comparisonOperator == NsgComparisonOperator.greaterOrEqual) {
      var pv = parameterValue;
      if (value is DateTime) {
        return value.compareTo(pv) >= 0;
      }
      return (value >= pv);
    } else if (comparisonOperator == NsgComparisonOperator.lessOrEqual) {
      var pv = parameterValue;
      if (value is DateTime) {
        return value.compareTo(pv) <= 0;
      }
      return (value <= pv);
    } else if (comparisonOperator == NsgComparisonOperator.greater) {
      var pv = parameterValue;
      if (value is DateTime) {
        return value.compareTo(pv) == 1;
      }
      return (value > pv);
    } else if (comparisonOperator == NsgComparisonOperator.less) {
      var pv = parameterValue;
      if (value is DateTime) {
        return value.compareTo(pv) == -1;
      }
      return (value < pv);
    } else if (comparisonOperator == NsgComparisonOperator.notContainWords) {
      var words = parameterValue.toString().split(' ');
      value = value.toString().toLowerCase();
      return !words.every(((e) => value.contains(e.toLowerCase())));
    } else if (comparisonOperator == NsgComparisonOperator.inGroup) {
      return ((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.groupsFrom) {
      return ((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.notGroupsFrom) {
      return !((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.equalOrEmpty) {
      var pv = parameterValue;
      if (parameterValue is NsgEnum) {
        pv = (parameterValue as NsgEnum).value;
      } else if (parameterValue is NsgDataItem) {
        pv = (parameterValue as NsgDataItem).id;
      }
      return (value == pv || value == null || value == '');
    } else if (comparisonOperator == NsgComparisonOperator.notInList) {
      return !((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.notBeginWith) {
      return !(value.toString().toLowerCase().startsWith(parameterValue.toString().toLowerCase()));
    } else if (comparisonOperator == NsgComparisonOperator.notEndWith) {
      return !(value.toString().toLowerCase().endsWith(parameterValue.toString().toLowerCase()));
    } else if (comparisonOperator == NsgComparisonOperator.notContain) {
      return !(value.toString().toLowerCase().contains(parameterValue.toString().toLowerCase()));
    } else if (comparisonOperator == NsgComparisonOperator.notInGroup) {
      return !((parameterValue as List).contains(value));
    } else if (comparisonOperator == NsgComparisonOperator.notEqualOrEmpty) {
      var pv = parameterValue;
      if (parameterValue is NsgEnum) {
        pv = (parameterValue as NsgEnum).value;
      } else if (parameterValue is NsgDataItem) {
        pv = (parameterValue as NsgDataItem).id;
      }
      return (value != pv && value != null && value != '');
    } else if (comparisonOperator == NsgComparisonOperator.typeIn) {
      return (parameterValue as List).contains(value.runtimeType);
    } else {
      return false;
    }
  }

  @override
  String toString() {
    return toStringFormatted(0);
  }

  String toStringFormatted(int indentLevel) {
    if (parameterValue is NsgCompare) {
      var nested = (parameterValue as NsgCompare)._toStringFormatted(indentLevel);
      return '$parameterName ${comparisonOperator.toString()} $nested';
    }

    var operatorStr = _getOperatorSymbol();
    var valueStr = _getValueString();

    return '$parameterName $operatorStr $valueStr';
  }

  String _getOperatorSymbol() {
    switch (comparisonOperator) {
      case NsgComparisonOperator.equal:
        return '=';
      case NsgComparisonOperator.notEqual:
        return '≠';
      case NsgComparisonOperator.beginWith:
        return 'startsWith';
      case NsgComparisonOperator.contain:
        return '⊃';
      case NsgComparisonOperator.containWords:
        return '⊃ words';
      case NsgComparisonOperator.endWith:
        return 'endsWith';
      case NsgComparisonOperator.inList:
        return '∈';
      case NsgComparisonOperator.typeEqual:
        return 'type =';
      case NsgComparisonOperator.typeNotEqual:
        return 'type ≠';
      case NsgComparisonOperator.greaterOrEqual:
        return '≥';
      case NsgComparisonOperator.lessOrEqual:
        return '≤';
      case NsgComparisonOperator.greater:
        return '>';
      case NsgComparisonOperator.less:
        return '<';
      case NsgComparisonOperator.notContainWords:
        return '⊄ words';
      case NsgComparisonOperator.inGroup:
        return '∈ group';
      case NsgComparisonOperator.groupsFrom:
        return 'groupsFrom';
      case NsgComparisonOperator.notGroupsFrom:
        return '¬groupsFrom';
      case NsgComparisonOperator.equalOrEmpty:
        return '= ∅';
      case NsgComparisonOperator.notInList:
        return '∉';
      case NsgComparisonOperator.notBeginWith:
        return '¬startsWith';
      case NsgComparisonOperator.notEndWith:
        return '¬endsWith';
      case NsgComparisonOperator.notContain:
        return '⊄';
      case NsgComparisonOperator.notInGroup:
        return '∉ group';
      case NsgComparisonOperator.notEqualOrEmpty:
        return '≠ ∅';
      case NsgComparisonOperator.typeIn:
        return 'type ∈';
      case NsgComparisonOperator.compare:
        return '';
      default:
        return '=';
    }
  }

  String _getValueString() {
    if (parameterValue is DateTime) {
      return '"${(parameterValue as DateTime).toIso8601String()}"';
    } else if (parameterValue is NsgEnum) {
      return '"${(parameterValue as NsgEnum).name}"';
    } else if (parameterValue is NsgDataItem) {
      if (comparisonOperator == NsgComparisonOperator.typeEqual || comparisonOperator == NsgComparisonOperator.typeNotEqual) {
        return '"${(parameterValue as NsgDataItem).typeName}"';
      } else {
        return '"${(parameterValue as NsgDataItem).id}"';
      }
    } else if (parameterValue is List) {
      var list = parameterValue as List;
      if (list.isEmpty) return '[]';

      if (list.first is NsgEnum) {
        var values = list.map((e) => '"${(e as NsgEnum).name}"').join(', ');
        return '[$values]';
      } else if (list.first is NsgDataItem) {
        var values = list.map((e) => '"${(e as NsgDataItem).id}"').join(', ');
        return '[$values]';
      } else {
        var values = list.map((e) => '"$e"').join(', ');
        return '[$values]';
      }
    } else if (parameterValue is String) {
      return '"$parameterValue"';
    } else {
      return parameterValue.toString();
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
