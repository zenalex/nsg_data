import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/nsg_data_delete.dart';
import 'package:nsg_data/v2/base/nsg_data_source.dart';

class NsgRemoteDataSource implements NsgDataSource {
  const NsgRemoteDataSource();

  @override
  Future<Iterable<T>> fetchItems<T extends NsgDataItem>({NsgDataRequestParams? params, Iterable<String>? loadReference}) async {
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.server);
    return request.requestItems(filter: params, loadReference: loadReference?.toList());
  }

  @override
  Future<T?> fetchById<T extends NsgDataItem>(String id, {Iterable<String>? loadReference}) async {
    final prototype = NsgDataClient.client.getNewObject(T) as T;
    final filter = NsgDataRequestParams()..compare.add(name: prototype.primaryKeyField, value: id, comparisonOperator: NsgComparisonOperator.equal);
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.server);
    final item = await request.requestItem(filter: filter, loadReference: loadReference?.toList());
    return item.isEmpty ? null : item;
  }

  @override
  Future<T> upsert<T extends NsgDataItem>(T item, {Iterable<String>? loadReference}) async {
    item.storageType = NsgDataStorageType.server;
    final post = NsgDataPost<T>(dataItemType: T)..itemsToPost = [item];
    final saved = await post.postItem(loadReference: loadReference?.toList());
    if (saved == null) {
      throw Exception('Save failed for $T');
    }
    return saved;
  }

  @override
  Future<Iterable<T>> upsertMany<T extends NsgDataItem>(Iterable<T> items, {Iterable<String>? loadReference}) async {
    for (final item in items) {
      item.storageType = NsgDataStorageType.server;
    }
    final post = NsgDataPost<T>(dataItemType: T)..itemsToPost = items.toList();
    return post.postItems(loadReference: loadReference?.toList());
  }

  @override
  Future<void> deleteMany<T extends NsgDataItem>(Iterable<T> items) async {
    if (items.isEmpty) {
      return;
    }
    final delete = NsgDataDelete<T>(dataItemType: T, itemsToDelete: items.toList());
    await delete.deleteItems();
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
    final request = NsgDataRequest<T>(dataItemType: T, storageType: NsgDataStorageType.server);
    final requestParams = params?.clone() ?? NsgDataRequestParams();
    requestParams.referenceList = null;
    requestParams.count = 0;
    await request.requestItems(filter: requestParams);
    return request.totalCount ?? 0;
  }
}
