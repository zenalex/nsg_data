import 'dart:async';

import 'package:get_it/get_it.dart';

class NsgGet {
  NsgGet();

  static final NsgGet _instance = NsgGet();

  /// access to the Singleton instance of GetIt
  static NsgGet get instance => _instance;

  static put<T extends Object>(
    NsgGetFactoryFunc<T> factoryFunc, {
    String? instanceName,
    NsgGetDisposingFunc<T>? disposeFunc,
  }) {
    instance.register(factoryFunc, instanceName: instanceName, disposeFunc: disposeFunc);
  }

  static find<T extends Object>({String? instanceName}) {
    instance.get(instanceName: instanceName);
  }

  void register<T extends Object>(
    NsgGetFactoryFunc<T> factoryFunc, {
    String? instanceName,
    NsgGetDisposingFunc<T>? disposeFunc,
  }) {
    if (GetIt.instance.isRegistered<T>()) {
      return;
    }
    GetIt.instance.registerLazySingleton<T>(factoryFunc, instanceName: instanceName, dispose: disposeFunc);
  }

  T get<T>({String? instanceName}) {
    return GetIt.instance<T>(instanceName: instanceName);
  }
}

typedef NsgGetFactoryFunc<T> = T Function();
typedef NsgGetDisposingFunc<T> = FutureOr Function(T param);
