import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/riverpod/core/query/nsg_list_query.dart';
import 'package:nsg_data/riverpod/core/repository/nsg_fetch_result.dart';

abstract class NsgEntityRepository<T extends NsgDataItem> {
  Type get dataType;

  Future<NsgFetchResult<T>> fetchList(NsgListQuery query);

  Future<T> fetchItem(String id, {List<String>? referenceList});

  Future<T> createDraft();

  Future<T> cloneAsDraft(T item);

  Future<T> save(T item);

  Future<void> delete(T item);

  Future<void> deleteMany(List<T> items);
}
