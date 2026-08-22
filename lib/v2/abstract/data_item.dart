import 'package:flutter/foundation.dart';

/// DataItem is a base interface for all data items. Immutable is main feature of the data item, that may system be reactive on it.
@immutable
abstract interface class DataItem {
  String get id;

  /// Convert the data item to a JSON map.
  Map<String, dynamic> toJson();

  /// Convert a JSON map to a data item.
  /// [json] The JSON map to convert.
  DataItem fromJson(Map<String, dynamic> json);

  /// Create a copy of the data item with the given id.
  /// [id] The id to set.
  DataItem copyWith({String? id});
}
