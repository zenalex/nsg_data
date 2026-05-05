import 'dart:async';

import 'package:nsg_data/v2/abstract/di.dart';
import 'package:nsg_data/v2/abstract/lifecycle.dart';

class NsgDI implements DI {
  final Map<(Type, String?), Lifecycle> bindings = {};

  @override
  FutureOr<void> bind<T extends Lifecycle>(T instance, [String? qualifier]) async {
    bindings[(T, qualifier)] = instance;
    await instance.init();
  }

  @override
  FutureOr<void> unbind<T extends Lifecycle>([String? qualifier]) async {
    final instance = await find<T>();
    await instance.dispose();
    bindings.remove((T, qualifier));
  }

  @override
  FutureOr<T> find<T extends Lifecycle>([String? qualifier]) async {
    return bindings[(T, qualifier)] as T;
  }

  @override
  FutureOr<T?> findOrNull<T extends Lifecycle>([String? qualifier]) async {
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
