import 'dart:convert';

import 'package:nsg_data/nsg_data.dart';

class NsgDataRequestParams {
  int top;
  int count;
  Map<String, dynamic>? params;
  String? sorting;
  String? readNestedField;
  NsgCompare? compare;

  Map<String, dynamic> toJson() {
    var filter = <String, dynamic>{};
    if (top != 0) filter['Top'] = jsonEncode(top); //.toString();
    if (count != 0) filter['Count'] = jsonEncode(count); //.toString();
    if (sorting != null) filter['Sorting'] = jsonEncode(sorting);
    if (readNestedField != null) filter['ReadNestedField'] = readNestedField.toString();
    if (compare != null) filter['Compare'] = compare?.toJson();
    if (params != null) filter.addAll(params!);
    return filter;
  }

  NsgDataRequestParams({this.top = 0, this.count = 0, this.params, this.sorting, this.readNestedField, this.compare});
}
