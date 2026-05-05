import 'dart:async';

import 'package:nsg_data/v2/abstract/app_navigator.dart';
import 'package:nsg_data/navigator/nsg_navigator.dart' as nsg_navigator;

class NsgNavigatorV2 implements AppNavigator {
  @override
  FutureOr<void> push(String routeName) {
    nsg_navigator.NsgNavigator.push(routeName);
  }

  @override
  FutureOr<void> pop() {
    nsg_navigator.NsgNavigator.pop();
  }

  @override
  FutureOr<void> go(String routeName) {
    nsg_navigator.NsgNavigator.go(routeName);
  }

  @override
  FutureOr<void> clear() {
    nsg_navigator.NsgNavigator.go(nsg_navigator.NsgNavigator.initialRoute ?? "/");
  }
}
