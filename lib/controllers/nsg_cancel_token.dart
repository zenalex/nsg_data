import 'dart:async';
import 'package:dio/dio.dart';
import 'package:nsg_data/helpers/nsg_data_guid.dart';

class NsgCancelToken {
  static final Object _scopeKey = Object();
  static NsgCancelToken? get current {
    final scope = Zone.current[_scopeKey] as _CancelScope?;
    return scope != null && scope.active ? scope.token : null;
  }

  /// Async work inherits the token; null explicitly isolates a non-cancellable operation.
  static T runScoped<T>(NsgCancelToken? token, T Function() body) {
    final scope = _CancelScope(token);
    try {
      final result = runZoned(body, zoneValues: {_scopeKey: scope});
      if (result is Future) {
        return result.whenComplete(() => scope.active = false) as T;
      }
      scope.active = false;
      return result;
    } catch (_) {
      scope.active = false;
      rethrow;
    }
  }

  String id = Guid.newGuid();
  bool isCalceled = false;
  CancelToken dioCancelToken = CancelToken();
  bool get isCancelled => isCalceled || dioCancelToken.isCancelled;
  void throwIfCancelled() {
    if (isCancelled) throw const NsgOperationCancelled();
  }

  void calcel() {
    isCalceled = true;
    dioCancelToken.cancel();
  }
}

class _CancelScope {
  _CancelScope(this.token);
  final NsgCancelToken? token;
  bool active = true;
}

/// A user decision, never a transport failure and never eligible for retry.
class NsgOperationCancelled implements Exception {
  const NsgOperationCancelled();
  @override
  String toString() => 'Operation cancelled';
}
