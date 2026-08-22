import 'package:nsg_data/v2/abstract/app_navigator.dart';
import 'package:nsg_data/v2/abstract/di.dart';

/// AppComposition is a composition of the app's data, controllers and dependencies. Main goal is to provide a way to compose the app's data, controllers and dependencies.
abstract interface class AppComposition {
  DI get di;
  AppNavigator get nav;
}
