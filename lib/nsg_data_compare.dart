import 'nsg_data_item.dart';

enum NsgLogicalOperator { And, Or }

class NsgCompareBase {
  /// Имя (имеет смысл при включении во внешний NsgCompare)
  String name = '';

  /// <summary>
  /// Признак включения(выключения) условия
  bool enabled = true;
}

class NsgCompare extends NsgCompareBase {
  /// логический оператор
  NsgLogicalOperator logicalOperator = NsgLogicalOperator.And;

  /// Признак условий по правам.
  bool isRights = false;

  // параметры сортировки
  List<NsgCompareParam> paramList = [];

  /// Проверка наличия в фильтре хотя бы одного условия
  bool get isEmpty {
    var res = true;
    this.paramList.forEach((param) {
      if (!param.enabled) return;
      //continue;
      if (param.parameterValue is NsgCompare)
        res = res && (param.parameterValue as NsgCompare).isEmpty;
      else
        res = false;
    });
    return res;
  }

  int get count => paramList.length;
  int get length => paramList.length;

  /// Возвращаем количество параметров с учетов всех вложенных параметров
  int get countAll {
    int i = 0;
    paramList.forEach((param) => {
          if (param.parameterValue is NsgCompare)
            {i += (param.parameterValue as NsgCompare).countAll}
          else
            {i++}
        });
    return i;
  }

  void add(
      {required String name,
      required dynamic value,
      String comparisonOperator = 'Equal'}) {
    paramList.add(new NsgCompareParam(
        parameterName: name,
        parameterValue: value,
        comparisonOperator: comparisonOperator));
  }

  String toXml() {
    StringBuffer sb =
        StringBuffer('<?xml version=\"1.0\" encoding=\"utf-16\"?>');
    sb.write(
        '<NsgCompare XMLSerializerVersion=\"1\" LogicalOperator=\"$logicalOperator\" type=\"NsgSoft.DataObjects.NsgCompare\">'
        '<Parameters>');
    _writeParamsToXml(sb, paramList);
    sb.write('</Parameters></NsgCompare>');
    return sb.toString();
  }

  void _writeParamsToXml(StringBuffer sb, List<NsgCompareParam> params) {
    params.forEach((param) {
      if (param.parameterValue is NsgCompare) {
        var iCmp = param.parameterValue as NsgCompare;
        sb.write(
            '<NsgCompareParam type=\"NsgSoft.DataObjects.NsgCompareParam\" Enabled=\"${param.enabled}\" Key=\"\" ValueMode=\"Manual\" '
            'ComparisonOperator=\"${param.comparisonOperator}\" ParameterName=\"${param.parameterName}\" Name="${param.name}">'
            '<ParameterValue LogicalOperator="${iCmp.logicalOperator}" type="NsgSoft.DataObjects.NsgCompare"><Parameters>');
        _writeParamsToXml(sb, iCmp.paramList);
        sb.write('</Parameters></ParameterValue></NsgCompareParam>');
      } else {
        sb.write(
            '<NsgCompareParam type=\"NsgSoft.DataObjects.NsgCompareParam\" Enabled=\"${param.enabled}\" Key=\"\" ValueMode=\"Manual\" '
            'ParameterValue=\"${param.type}|${param.parameterValue}\" ComparisonOperator=\"${param.comparisonOperator}\" '
            'ParameterName=\"${param.parameterName}\" Name="${param.name}" />');
      }
    });
  }
}

class NsgCompareParam extends NsgCompareBase {
  NsgCompareParam(
      {required this.parameterName,
      required this.parameterValue,
      comparisonOperator = 'Equal'}) {
    if (parameterValue is NsgDataItem) {
      parameterValue =
          parameterValue[(parameterValue as NsgDataItem).primaryKeyField];
    }
  }

  /// Значение
  String parameterName;

  /// Значение
  dynamic parameterValue;

  String get type {
    RegExp guidRegExp =
        RegExp(r"[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$");
    if (guidRegExp.hasMatch(parameterValue)) {
      return 'System.Guid';
    }
    if (parameterValue is double) {
      return 'System.Double';
    }
    if (parameterValue is int) {
      return 'System.Int64';
    }
    return 'System.String';
  }

  String comparisonOperator = 'Equal';
}
