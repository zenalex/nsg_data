import 'dart:async';

import 'package:nsg_data/nsg_data.dart';

/// DataSource is a source of data. It's responsible for fetching data from the source and providing a way to interact with the data.
abstract interface class DataSource {
  /// Fetch items from the source.
  /// [params] The parameters to fetch the items.
  /// [loadReference] The references to load.
  /// [return] The Iterable of items.
  FutureOr<Iterable<T>> fetchItems<T extends NsgDataItem>({NsgDataRequestParams? params, Iterable<String>? loadReference});

  /// Fetch an item by id from the source.
  /// [id] The id of the item to fetch.
  /// [loadReference] The references to load.
  /// [return] The item.
  FutureOr<T?> fetchById<T extends NsgDataItem>(String id, {Iterable<String>? loadReference});

  /// Upsert an item into the source.
  /// [item] The item to upsert.
  /// [loadReference] The references to load.
  /// [return] The upserted item.
  FutureOr<T> upsert<T extends NsgDataItem>(T item, {Iterable<String>? loadReference});

  /// Upsert many items into the source.
  /// [items] The items to upsert.
  /// [loadReference] The references to load.
  /// [return] The upserted items.
  FutureOr<Iterable<T>> upsertMany<T extends NsgDataItem>(Iterable<T> items, {Iterable<String>? loadReference});

  /// Delete many items from the source.
  /// [items] The items to delete.
  FutureOr<void> deleteMany<T extends NsgDataItem>(Iterable<T> items);

  /// Delete an item by id from the source.
  /// [id] The id of the item to delete.
  FutureOr<void> deleteById<T extends NsgDataItem>(String id);

  /// Select count of items from the source.
  /// [params] The parameters to select the count.
  /// [return] The count of items.
  FutureOr<int> selectCount<T extends NsgDataItem>({NsgDataRequestParams? params});
}
