import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/snapshot.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';

/// Controller is a base interface for all controllers.
abstract interface class Controller {
  /// Snapshot of the controller's state.
  Snapshot get snapshot;

  /// Load reference is a list of subitems that are needed to be loaded when the controller is loaded.
  Iterable<String> get loadReference;

  /// Request params is a list of parameters that are needed to be used when the controller is loaded.
  NsgDataRequestParams get requestParams;

  NsgControllerStatus get status;
}

abstract interface class QueryController<T extends NsgDataItem> implements Controller {
  /// If [filter] is provided, the controller will refresh the items that match the filter, else it will refresh all items. Needs for partially update
  /// If [loadReference] is provided, the controller will load the subitems, else it will pick loadReference from controller.
  /// If [requestParams] is omitted, implementers should use [requestParams] from this controller (view layer merges filters into it).
  FutureOr<void> refresh({Iterable<T>? items, Iterable<String>? loadReference, NsgDataRequestParams? requestParams});

  /// Load the items from the data source
  /// If [loadReference] is provided, the controller will load the subitems, else it will pick loadReference from controller
  /// If [requestParams] is provided, the controller will use it to request the items, else it will use the requestParams from controller
  FutureOr<Iterable<T>> load({NsgDataRequestParams? requestParams, Iterable<String>? loadReference});
}

abstract interface class CommandController<T extends NsgDataItem> implements Controller {
  /// Create a new item (it's method don't save the item to the data source, it's just a new item)
  FutureOr<T> create();

  /// Save the items to the data source
  /// If [filter] is provided, the controller will save the items that match the filter, else it will save all items. Needs for partially update
  /// If [loadReference] is provided, the controller will save the subitems, else it will save all subitems that match loadReference from controller
  FutureOr<Iterable<T>?> save({Iterable<T>? items, Iterable<String>? loadReference});

  /// Delete the items from the data source
  /// If [loadReference] is provided, the controller will delete the subitems, else it will pick loadReference from controller
  FutureOr<void> delete({Iterable<T>? items});
}
