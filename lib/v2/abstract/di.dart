import 'dart:async';

import 'package:nsg_data/v2/abstract/lifecycle.dart';

/// DI is a dependency injection container. It's responsible for managing the dependencies of the app.
abstract interface class DI<D extends Lifecycle> {
  /// Bind an instance to the DI container.
  /// [instance] The instance to bind.
  FutureOr<void> bind<T extends D>(T instance);

  /// Unbind an instance from the DI container.
  /// [instance] The instance to unbind.
  FutureOr<void> unbind<T extends D>();

  /// Find an instance from the DI container.
  /// [instance] The instance to find.
  FutureOr<T> find<T extends D>();

  /// Find an instance from the DI container or return null if not found.
  /// [instance] The instance to find.
  FutureOr<T?> findOrNull<T extends D>();

  /// Reset the DI container.
  FutureOr<void> reset();
}
