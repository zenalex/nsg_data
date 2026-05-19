import 'package:flutter/foundation.dart';
import 'package:nsg_data/v2/abstract/metrica.dart';

/// Debug [MetricaSink] that prints every event to the console via [debugPrint].
///
/// Only outputs in debug builds by default ([kDebugMode]).
/// Suitable for development; do not ship this as the only sink in production.
///
/// ```dart
/// NsgMetrica(sinks: [NsgConsoleSink()])
/// ```
class NsgConsoleSink implements MetricaSink {
  NsgConsoleSink({this.onlyInDebug = true});

  /// When `true` (default) events are only printed in [kDebugMode].
  final bool onlyInDebug;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> track(MetricaEvent event) async {
    if (onlyInDebug && !kDebugMode) return;

    final ts = (event.timestamp ?? DateTime.now()).toIso8601String();
    final params = event.params.isEmpty ? '' : ' | ${_formatParams(event.params)}';
    debugPrint('[NsgMetrica] $ts  ${event.name}$params');
  }

  String _formatParams(Map<String, Object?> params) {
    return params.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }
}
