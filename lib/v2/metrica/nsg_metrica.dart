import 'dart:async';

import 'package:nsg_data/v2/abstract/metrica.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';

/// Concrete composite implementation of [Metrica].
///
/// Forwards every [MetricaEvent] to all registered [MetricaSink]s.
/// [track] is synchronous (fire-and-forget) — each sink dispatches
/// asynchronously so that controller / UI code is never blocked.
///
/// ## Registration in DI
/// ```dart
/// await di.bind<NsgMetrica>(
///   NsgMetrica(sinks: [NsgConsoleSink(), MyFirebaseSink()]),
/// );
/// ```
///
/// ## Accessing from controllers / app code
/// ```dart
/// final metrica = di.findOrNull<NsgMetrica>();
/// metrica?.track(NsgMetricaUserActionEvent(action: 'button_tap'));
/// ```
class NsgMetrica implements Metrica, NsgLifecycle {
  NsgMetrica({List<MetricaSink>? sinks}) : _sinks = sinks?.toList() ?? [];

  final List<MetricaSink> _sinks;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  FutureOr<void> init() async {
    for (final sink in _sinks) {
      await sink.init();
    }
  }

  @override
  FutureOr<void> dispose() async {
    for (final sink in _sinks) {
      await sink.dispose();
    }
    _sinks.clear();
  }

  // -------------------------------------------------------------------------
  // Sink management
  // -------------------------------------------------------------------------

  @override
  FutureOr<void> addSink(MetricaSink sink) async {
    await sink.init();
    _sinks.add(sink);
  }

  @override
  FutureOr<void> removeSink(MetricaSink sink) async {
    _sinks.remove(sink);
    await sink.dispose();
  }

  // -------------------------------------------------------------------------
  // Tracking
  // -------------------------------------------------------------------------

  @override
  void track(MetricaEvent event) {
    for (final sink in List.unmodifiable(_sinks)) {
      try {
        sink.track(event);
      } catch (e, st) {
        // Sink errors must never propagate to the caller.
        // ignore: avoid_print
        print('[NsgMetrica] sink ${sink.runtimeType} threw: $e\n$st');
      }
    }
  }
}
