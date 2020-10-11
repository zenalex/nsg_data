class NsgDataRequestFilter {
  final int top;
  final int count;
  final List<String> idList;
  Map<String, String> toJson() {
    var filter = <String, String>{};
    if (top != 0) filter['Top'] = top.toString();
    if (count != 0) filter['Count'] = count.toString();
    if (idList != null) filter['IdList'] = idList.asMap().toString();
    return filter;
  }

  NsgDataRequestFilter({this.top = 0, this.count = 0, this.idList});
}
