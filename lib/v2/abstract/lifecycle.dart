import 'dart:async';

/// Lifecycle is a base interface for all lifecycle components.
abstract interface class Lifecycle {
  /// Initialize the lifecycle component.
  /// [return] A future that completes when the initialization is complete.
  FutureOr<void> init();

  /// Dispose the lifecycle component.
  /// [return] A future that completes when the disposal is complete.
  FutureOr<void> dispose();
}
