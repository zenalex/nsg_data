import 'dart:collection';

import 'package:nsg_data/nsg_data_item.dart';

class NsgFetchResult<T extends NsgDataItem> {
  final UnmodifiableListView<T> items;
  final int? totalCount;

  NsgFetchResult({required Iterable<T> items, this.totalCount})
    : items = UnmodifiableListView<T>(items.map((e) => e.clone() as T));
}
