import 'dart:convert';

import 'package:nsg_data/nsg_data.dart';

class NsgDataRequestParams {
  final int top;
  final int count;
  final List<String>? idList;
  final Map<String, dynamic>? params;
  String? sorting;
  String? readNestedField;
  NsgCompare? searchCriteria;

  Map<String, dynamic> toJson() {
    var filter = <String, dynamic>{};
    if (top != 0) filter['Top'] = top.toString();
    if (count != 0) filter['Count'] = count.toString();
    if (idList != null) filter['IdList'] = jsonEncode(idList);
    if (sorting != null) filter['Sorting'] = jsonEncode(sorting);
    if (readNestedField != null)
      filter['ReadNestedField'] = jsonEncode(readNestedField);
    if (searchCriteria != null)
      filter['SearchCriteriaXml'] = searchCriteria?.toXml();
    if (params != null) filter.addAll(params!);
    return filter;
  }

  NsgDataRequestParams(
      {this.top = 0,
      this.count = 0,
      this.idList,
      this.params,
      this.sorting,
      this.readNestedField,
      this.searchCriteria});
}
