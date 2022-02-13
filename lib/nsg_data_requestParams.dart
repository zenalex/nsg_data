import 'dart:convert';

class NsgDataRequestParams {
  final int top;
  final int count;
  final List<String>? idList;
  final Map<String, dynamic>? params;
  String? sortByField;
  String? readNestedField;

  //TODO: SearchCriteriaXml

  Map<String, dynamic> toJson() {
    var filter = <String, dynamic>{};
    if (top != 0) filter['Top'] = top.toString();
    if (count != 0) filter['Count'] = count.toString();
    if (idList != null) filter['IdList'] = jsonEncode(idList);
    if (sortByField != null) filter['SortByField'] = jsonEncode(sortByField);
    if (readNestedField != null)
      filter['ReadNestedField'] = jsonEncode(readNestedField);
    if (params != null) filter.addAll(params!);
    return filter;
  }

  NsgDataRequestParams(
      {this.top = 0,
      this.count = 0,
      this.idList,
      this.params,
      this.sortByField,
      this.readNestedField});
}
