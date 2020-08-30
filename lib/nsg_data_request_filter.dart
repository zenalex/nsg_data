class NsgDataRequestFilter {
  int top = 0;
  int count = 0;
  Map<String, String> toJson() {
    var filter = <String, String>{};
    if (top != 0) filter['Top'] = top.toString();
    if (count != 0) filter['Count'] = count.toString();
    return filter;
  }

  NsgDataRequestFilter({this.top, this.count});
}
