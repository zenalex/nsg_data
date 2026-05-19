import 'package:nsg_data/v2/abstract/app_composition.dart';
import 'package:nsg_data/v2/base/nsg_di.dart';
import 'package:nsg_data/v2/base/nsg_navigator.dart';

abstract interface class NsgAppComposition implements AppComposition {
  @override
  NsgDI get di;

  @override
  NsgNavigatorV2 get nav;
}
