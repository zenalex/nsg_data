import 'dart:async';

import 'package:get_it/get_it.dart';

import '../controllers/nsgBaseController.dart';

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
    instance.register<T>(factoryFunc,
        instanceName: instanceName, disposeFunc: disposeFunc);
  }

  static T find<T extends Object>({String? instanceName}) {
    return instance.get<T>(instanceName: instanceName);
  }

  void register<T extends Object>(
    NsgGetFactoryFunc<T> factoryFunc, {
    String? instanceName,
    NsgGetDisposingFunc<T>? disposeFunc,
  }) {
    if (GetIt.instance.isRegistered<T>()) {
      return;
    }
    var obj = factoryFunc();
    GetIt.instance.registerSingleton(obj,
        instanceName: instanceName, dispose: disposeFunc);
    if (obj is NsgBaseController) {
      obj.onInit();
    }
  }

  T get<T extends Object>({String? instanceName}) {
    return GetIt.instance<T>(instanceName: instanceName);
  }
}

typedef NsgGetFactoryFunc<T> = T Function();
typedef NsgGetDisposingFunc<T> = FutureOr Function(T param);
