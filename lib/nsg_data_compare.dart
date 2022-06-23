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
    map["ParamList"] = list;
    return map;
  }

  // String toXml() {
  //   StringBuffer sb =
  //       StringBuffer('<?xml version=\"1.0\" encoding=\"utf-16\"?>');
  //   sb.write(
  //       '<NsgCompare XMLSerializerVersion=\"1\" LogicalOperator=\"$logicalOperator\" type=\"NsgSoft.DataObjects.NsgCompare\">'
  //       '<Parameters>');
  //   _writeParamsToXml(sb, paramList);
  //   sb.write('</Parameters></NsgCompare>');
  //   return sb.toString();
  // }

  // void _writeParamsToXml(StringBuffer sb, List<NsgCompareParam> params) {
  //   params.forEach((param) {
  //     if (param.parameterValue is NsgCompare) {
  //       var iCmp = param.parameterValue as NsgCompare;
  //       sb.write(
  //           '<NsgCompareParam type=\"NsgSoft.DataObjects.NsgCompareParam\" Enabled=\"${param.enabled}\" Key=\"\" ValueMode=\"Manual\" '
  //           'ComparisonOperator=\"${param.comparisonOperator}\" ParameterName=\"${param.parameterName}\" Name="${param.name}">'
  //           '<ParameterValue LogicalOperator="${iCmp.logicalOperator}" type="NsgSoft.DataObjects.NsgCompare"><Parameters>');
  //       _writeParamsToXml(sb, iCmp.paramList);
  //       sb.write('</Parameters></ParameterValue></NsgCompareParam>');
  //     } else {
  //       sb.write(
  //           '<NsgCompareParam type=\"NsgSoft.DataObjects.NsgCompareParam\" Enabled=\"${param.enabled}\" Key=\"\" ValueMode=\"Manual\" '
  //           'ParameterValue=\"${param.type}|${param.parameterValue}\" ComparisonOperator=\"${param.comparisonOperator}\" '
  //           'ParameterName=\"${param.parameterName}\" Name="${param.name}" />');
  //     }
  //   });
  // }
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
    } else if (parameterValue is NsgDataItem) {
      map["Value"] = (parameterValue as NsgDataItem).id;
    } else if (parameterValue is List && (parameterValue as List).length > 0 && (parameterValue as List).first is NsgDataItem) {
      var idList = <String>[];
      for (NsgDataItem e in parameterValue as List) {
        idList.add(e.id);
      }
      map["Value"] = idList;
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

  

