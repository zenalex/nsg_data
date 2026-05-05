import 'package:nsg_data/v2/abstract/snapshot.dart';

/// Store is a store for the controller's state. It's responsible for storing the controller's state and providing a way to get the state. Can be stored in the memory or in the database indenpendently from the controller.
abstract interface class Store {
  Snapshot get snapshot;
  set snapshot(covariant Snapshot value);

  void update(covariant Snapshot next);
}
