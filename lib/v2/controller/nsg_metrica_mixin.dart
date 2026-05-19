import 'package:nsg_data/v2/abstract/metrica.dart';
import 'package:nsg_data/v2/metrica/nsg_metrica_events.dart';

/// Opt-in mixin that adds [NsgMetrica] tracking to any controller.
///
/// Concrete controllers that `with NsgMetricaMixin` must implement [metrica]
/// (returning `null` disables tracking without errors) and may override
/// [metricaControllerKey] to provide a stable identifier for the controller.
///
/// ## Usage in a custom controller
/// ```dart
/// class MyController extends NsgDataControllerV2<MyItem>
///     with NsgMetricaMixin {
///   @override
///   final Metrica? metrica;
///
///   MyController({required super.dataSource, this.metrica});
/// }
/// ```
mixin NsgMetricaMixin {
  /// Analytics service instance. Return `null` to disable tracking silently.
  Metrica? get metrica;

  /// Stable string key used to identify this controller in analytics events.
  /// Defaults to the runtime type name; override for a friendlier label.
  String get metricaControllerKey => runtimeType.toString();

  // -------------------------------------------------------------------------
  // Helper methods — used by DataController / ViewController hooks
  // -------------------------------------------------------------------------

  void trackMetricaLoad({required int itemCount, required int durationMs}) {
    metrica?.track(NsgMetricaLoadEvent(
      controllerKey: metricaControllerKey,
      itemCount: itemCount,
      durationMs: durationMs,
    ));
  }

  void trackMetricaSave({required int itemCount, required int durationMs}) {
    metrica?.track(NsgMetricaSaveEvent(
      controllerKey: metricaControllerKey,
      itemCount: itemCount,
      durationMs: durationMs,
    ));
  }

  void trackMetricaDelete({required int itemCount}) {
    metrica?.track(NsgMetricaDeleteEvent(
      controllerKey: metricaControllerKey,
      itemCount: itemCount,
    ));
  }

  void trackMetricaError(Exception error, [StackTrace? stackTrace]) {
    metrica?.track(NsgMetricaErrorEvent(
      controllerKey: metricaControllerKey,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void trackMetricaRetry(Exception error) {
    metrica?.track(NsgMetricaRetryEvent(
      controllerKey: metricaControllerKey,
      error: error,
    ));
  }

  void trackMetricaInit() {
    metrica?.track(NsgMetricaInitEvent(
      controllerKey: metricaControllerKey,
    ));
  }

  void trackMetricaDispose() {
    metrica?.track(NsgMetricaDisposeEvent(
      controllerKey: metricaControllerKey,
    ));
  }

  /// Track an arbitrary [MetricaEvent] directly.
  void trackEvent(MetricaEvent event) {
    metrica?.track(event);
  }
}
