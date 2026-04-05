import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/nsg_data_delete.dart';

class NsgDefaultEntityRepository<T extends NsgDataItem>
    implements NsgEntityRepository<T> {
  @override
  final Type dataType;

  final NsgDataStorageType storageType;

  @override
  NsgDefaultEntityRepository({
    required this.dataType,
    this.storageType = NsgDataStorageType.server,
  });

  @override
  Future<NsgFetchResult<T>> fetchList(NsgListQuery query) async {
    final request = NsgDataRequest<T>(
      dataItemType: dataType,
      storageType: storageType,
    );
    final items = await request.requestItems(
      filter: query.requestParams.clone(),
    );
    return NsgFetchResult<T>(items: items, totalCount: request.totalCount);
  }

  @override
  Future<T> fetchItem(String id, {List<String>? referenceList}) async {
    final prototype = NsgDataClient.client.getNewObject(dataType) as T;
    final compare = NsgCompare();
    compare.add(name: prototype.primaryKeyField, value: id);
    final filter = NsgDataRequestParams(compare: compare);
    final request = NsgDataRequest<T>(
      dataItemType: dataType,
      storageType: storageType,
    );
    final item = await request.requestItem(
      filter: filter,
      loadReference: referenceList,
    );
    return item.clone() as T;
  }

  @override
  Future<T> createDraft() async {
    final item = NsgDataClient.client.getNewObject(dataType) as T;
    if (item.createOnServer) {
      final request = NsgDataRequest<T>(
        dataItemType: dataType,
        storageType: storageType,
      );
      final created = await request.requestItem(
        method: 'POST',
        function: '${item.apiRequestItems}/Create',
      );
      created.storageType = storageType;
      return created.clone() as T;
    } else {
      item.newRecordFill();
    }
    item.state = NsgDataItemState.create;
    item.docState = NsgDataItemDocState.created;
    item.storageType = storageType;
    return item.clone() as T;
  }

  @override
  Future<T> cloneAsDraft(T item) async {
    return item.clone() as T;
  }

  @override
  Future<T> save(T item) async {
    final post = NsgDataPost<T>(dataItemType: dataType)..itemsToPost = [item];
    final saved = await post.postItem();
    if (saved == null) {
      throw StateError('Save returned no data for $dataType');
    }
    return saved.clone() as T;
  }

  @override
  Future<void> deleteMany(List<T> items) async {
    if (items.isEmpty) return;
    final delete = NsgDataDelete<T>(
      dataItemType: dataType,
      itemsToDelete: List<T>.from(items),
    );
    await delete.deleteItems();
  }

  @override
  Future<void> delete(T item) {
    return deleteMany([item]);
  }
}
