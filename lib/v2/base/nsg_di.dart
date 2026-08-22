import 'dart:async';

import 'package:nsg_data/v2/abstract/di.dart';
import 'package:nsg_data/v2/abstract/lifecycle.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';

class NsgDI implements DI<NsgLifecycle> {
  final Map<(Type, String?), Lifecycle> bindings = {};

  @override
  FutureOr<void> bind<T extends NsgLifecycle>(T instance, [String? qualifier]) async {
    bindings[(T, qualifier)] = instance;
    await instance.init();
  }

  @override
  FutureOr<void> unbind<T extends NsgLifecycle>([String? qualifier]) async {
    final instance = find<T>();
    await instance.dispose();
    bindings.remove((T, qualifier));
  }

  @override
  T find<T extends NsgLifecycle>([String? qualifier]) {
    return bindings[(T, qualifier)] as T;
  }

  @override
  T? findOrNull<T extends NsgLifecycle>([String? qualifier]) {
    return bindings[(T, qualifier)] as T?;
  }

  @override
  FutureOr<void> reset() async {
    for (final instance in bindings.values) {
      await instance.dispose();
    }
    bindings.clear();
  }
}
