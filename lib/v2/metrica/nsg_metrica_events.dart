import 'package:nsg_data/v2/abstract/metrica.dart';

// ---------------------------------------------------------------------------
// Automatic events — emitted by DataController / ViewController hooks
// ---------------------------------------------------------------------------

/// Emitted after a successful [NsgDataQueryControllerV2.refresh] call.
class NsgMetricaLoadEvent extends MetricaEvent {
  NsgMetricaLoadEvent({
    required this.controllerKey,
    required this.itemCount,
    required this.durationMs,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.load',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
            'item_count': itemCount,
            'duration_ms': durationMs,
          },
        );

  final String controllerKey;
  final int itemCount;
  final int durationMs;
}

/// Emitted after a successful [NsgDataCommandControllerV2.save] call.
class NsgMetricaSaveEvent extends MetricaEvent {
  NsgMetricaSaveEvent({
    required this.controllerKey,
    required this.itemCount,
    required this.durationMs,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.save',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
            'item_count': itemCount,
            'duration_ms': durationMs,
          },
        );

  final String controllerKey;
  final int itemCount;
  final int durationMs;
}

/// Emitted after a successful [NsgDataCommandControllerV2.delete] call.
class NsgMetricaDeleteEvent extends MetricaEvent {
  NsgMetricaDeleteEvent({
    required this.controllerKey,
    required this.itemCount,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.delete',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
            'item_count': itemCount,
          },
        );

  final String controllerKey;
  final int itemCount;
}

/// Emitted when a controller operation catches an [Exception].
class NsgMetricaErrorEvent extends MetricaEvent {
  NsgMetricaErrorEvent({
    required this.controllerKey,
    required this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.error',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
            'error': error.toString(),
            if (stackTrace != null) 'stack_trace': stackTrace.toString(),
          },
        );

  final String controllerKey;
  final Exception error;
  final StackTrace? stackTrace;
}

/// Emitted each time a retry is triggered via [DataController.onRetry].
class NsgMetricaRetryEvent extends MetricaEvent {
  NsgMetricaRetryEvent({
    required this.controllerKey,
    required this.error,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.retry',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
            'error': error.toString(),
          },
        );

  final String controllerKey;
  final Exception error;
}

/// Emitted when a controller completes [NsgLifecycle.init].
class NsgMetricaInitEvent extends MetricaEvent {
  NsgMetricaInitEvent({
    required this.controllerKey,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.init',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
          },
        );

  final String controllerKey;
}

/// Emitted when a controller completes [NsgLifecycle.dispose].
class NsgMetricaDisposeEvent extends MetricaEvent {
  NsgMetricaDisposeEvent({
    required this.controllerKey,
    DateTime? timestamp,
  }) : super(
          name: 'nsg.controller.dispose',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'controller_key': controllerKey,
          },
        );

  final String controllerKey;
}

// ---------------------------------------------------------------------------
// Manual events — app code calls NsgMetrica.instance.track(...)
// ---------------------------------------------------------------------------

/// Navigation between pages/routes.
class NsgMetricaNavigationEvent extends MetricaEvent {
  NsgMetricaNavigationEvent({
    required this.route,
    this.fromRoute,
    Map<String, Object?> extraParams = const {},
    DateTime? timestamp,
  }) : super(
          name: 'nsg.navigation',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'route': route,
            'from_route': fromRoute,
            ...extraParams,
          },
        );

  final String route;
  final String? fromRoute;
}

/// Explicit user interaction (button tap, item selection, etc.).
class NsgMetricaUserActionEvent extends MetricaEvent {
  NsgMetricaUserActionEvent({
    required this.action,
    this.target,
    Map<String, Object?> extraParams = const {},
    DateTime? timestamp,
  }) : super(
          name: 'nsg.user_action',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'action': action,
            'target': target,
            ...extraParams,
          },
        );

  final String action;
  final String? target;
}

/// Arbitrary performance measurement (e.g. image load, render time).
class NsgMetricaPerformanceEvent extends MetricaEvent {
  NsgMetricaPerformanceEvent({
    required this.label,
    required this.durationMs,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) : super(
          name: 'nsg.performance',
          timestamp: timestamp ?? DateTime.now(),
          params: {
            'label': label,
            'duration_ms': durationMs,
            ...metadata,
          },
        );

  final String label;
  final int durationMs;
}
