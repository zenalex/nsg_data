import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/base/nsg_data_source.dart';

class NsgLocalDataSource implements NsgDataSource {
  const NsgLocalDataSource();

  @override
  Future<Iterable<T>> fetchItems<T extends NsgDataItem>({NsgDataRequestParams? params, Iterable<String>? loadReference}) async {
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.local);
    return request.requestItems(filter: params ?? NsgDataRequestParams(), loadReference: loadReference?.toList());
  }

  @override
  Future<T?> fetchById<T extends NsgDataItem>(String id, {Iterable<String>? loadReference}) async {
    final prototype = NsgDataClient.client.getNewObject(T) as T;
    final filter = NsgDataRequestParams()..compare.add(name: prototype.primaryKeyField, value: id, comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.local);
    final item = await request.requestItem(filter: filter, loadReference: loadReference?.toList());
    return item.isEmpty ? null : item;
  }

  @override
  Future<T> upsert<T extends NsgDataItem>(T item, {Iterable<String>? loadReference}) async {
    item.storageType = NsgDataStorageType.local;
    await NsgLocalDb.instance.postItems([item]);
    return item;
  }

  @override
  Future<Iterable<T>> upsertMany<T extends NsgDataItem>(Iterable<T> items, {Iterable<String>? loadReference}) async {
    for (final item in items) {
      item.storageType = NsgDataStorageType.local;
    }
    await NsgLocalDb.instance.postItems(items.cast<NsgDataItem>().toList());
    return items;
  }

  @override
  Future<void> deleteMany<T extends NsgDataItem>(Iterable<T> items) async {
    if (items.isEmpty) {
      return;
    }
    await NsgLocalDb.instance.deleteItems(items.cast<NsgDataItem>().toList());
  }

  @override
  Future<void> deleteById<T extends NsgDataItem>(String id) async {
    final item = await fetchById<T>(id);
    if (item != null) {
      await deleteMany<T>([item]);
    }
  }

  @override
  Future<int> selectCount<T extends NsgDataItem>({NsgDataRequestParams? params}) async {
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.local);
    final requestParams = params?.clone() ?? NsgDataRequestParams();
    requestParams.referenceList = [];
    requestParams.count = 0;
    await request.requestItems(filter: requestParams);
    return request.totalCount ?? 0;
  }
}
