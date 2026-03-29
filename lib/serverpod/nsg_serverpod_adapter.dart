import 'dart:async';

import 'package:nsg_data/nsg_data.dart';

enum NsgRemoteProviderKind { rest, serverpod }

class NsgServerpodListResult {
  final List<dynamic> items;
  final int? totalCount;

  const NsgServerpodListResult({required this.items, this.totalCount});
}

class NsgServerpodRequestContext {
  final NsgDataProvider provider;
  final NsgDataItem prototype;
  final Type dataItemType;
  final NsgDataRequestParams filter;
  final List<String> loadReference;
  final String tag;
  final String function;

  const NsgServerpodRequestContext({
    required this.provider,
    required this.prototype,
    required this.dataItemType,
    required this.filter,
    required this.loadReference,
    required this.tag,
    required this.function,
  });
}

class NsgServerpodMutationContext {
  final NsgDataProvider provider;
  final NsgDataItem prototype;
  final Type dataItemType;
  final List<NsgDataItem> items;
  final List<String> loadReference;
  final String tag;
  final String function;

  const NsgServerpodMutationContext({
    required this.provider,
    required this.prototype,
    required this.dataItemType,
    required this.items,
    required this.loadReference,
    required this.tag,
    required this.function,
  });
}

typedef NsgServerpodFetchItems = FutureOr<dynamic> Function(NsgServerpodRequestContext context);
typedef NsgServerpodPostItems = FutureOr<dynamic> Function(NsgServerpodMutationContext context);
typedef NsgServerpodDeleteItems = FutureOr<void> Function(NsgServerpodMutationContext context);

class NsgServerpodAdapter {
  final NsgServerpodFetchItems fetchItems;
  final NsgServerpodPostItems postItems;
  final NsgServerpodDeleteItems deleteItems;

  const NsgServerpodAdapter({
    required this.fetchItems,
    required this.postItems,
    required this.deleteItems,
  });
}

class NsgServerpodFilterHelper {
  static List<NsgDataItem> applyRequestParams(List<NsgDataItem> items, NsgDataRequestParams filter) {
    var filtered = items.where((item) {
      if (!filter.showDeletedObjects && item.docState == NsgDataItemDocState.deleted) {
        return false;
      }
      if (filter.compare.isNotEmpty && !filter.compare.isValid(item)) {
        return false;
      }
      return true;
    }).toList();

    if ((filter.sorting ?? '').isNotEmpty) {
      final sorting = NsgSorting();
      sorting.addStringParams(filter.sorting!);
      filtered.sort((a, b) {
        for (final param in sorting.paramList) {
          final fieldA = a.getField(param.parameterName);
          final result = fieldA.compareTo(a, b);
          if (result == 0) continue;
          if (param.direction == NsgSortingDirection.ascending) {
            return result;
          }
          return result == 1 ? -1 : 1;
        }
        return 0;
      });
    }

    if (filter.top > 0) {
      if (filter.top >= filtered.length) {
        return <NsgDataItem>[];
      }
      filtered = filtered.skip(filter.top).toList();
    }

    if (filter.count > 0 && filter.count < filtered.length) {
      filtered = filtered.take(filter.count).toList();
    }

    return filtered;
  }
}
