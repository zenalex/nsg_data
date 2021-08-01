import 'dart:convert';

class NsgDataRequestParams {
  final int top;
  final int count;
  final List<String>? idList;
  final Map<String, String>? params;
  Map<String, String> toJson() {
    var filter = <String, String>{};
    if (top != 0) filter['Top'] = top.toString();
    if (count != 0) filter['Count'] = count.toString();
    if (idList != null) filter['IdList'] = jsonEncode(idList);
    if (params != null) filter.addAll(params!);
    return filter;
  }

  NsgDataRequestParams(
      {this.top = 0, this.count = 0, this.idList, this.params});
}
