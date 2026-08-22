import 'dart:async';

import 'package:nsg_data/v2/abstract/lifecycle.dart';

/// Base class for all metrica events.
/// Subclass this to create custom event types in the app layer.
abstract class MetricaEvent {
  const MetricaEvent({
    required this.name,
    this.params = const {},
    this.timestamp,
  });

  final String name;

  /// UTC timestamp of when the event was created.
  /// Defaults to [DateTime.now()] if not supplied.
  final DateTime? timestamp;

  final Map<String, Object?> params;
}

/// Sink that receives and forwards [MetricaEvent]s to a specific backend
/// (Firebase Analytics, custom HTTP endpoint, console, etc.).
///
/// [MetricaSink] is a [Lifecycle] component — register it via [NsgDI] or
/// manage its lifetime explicitly with [init]/[dispose].
abstract class MetricaSink implements Lifecycle {
  /// Called by [Metrica] for every tracked event.
  /// Implementations must not throw synchronously; wrap errors internally.
  Future<void> track(MetricaEvent event);
}

/// Central analytics service.
///
/// Collect events with [track]. Sinks can be added/removed at runtime via
/// [addSink]/[removeSink]. [Metrica] itself is a [Lifecycle] component so it
/// can be registered in [NsgDI] and have all sinks initialised/disposed
/// automatically.
abstract class Metrica implements Lifecycle {
  /// Forward [event] to every registered [MetricaSink].
  /// This call is intentionally synchronous (fire-and-forget); each sink
  /// dispatches asynchronously so the caller is never blocked.
  void track(MetricaEvent event);

  /// Dynamically attach a [sink]. [sink.init()] is called immediately.
  FutureOr<void> addSink(MetricaSink sink);

  /// Dynamically detach a [sink]. [sink.dispose()] is called immediately.
  FutureOr<void> removeSink(MetricaSink sink);
}
