import 'dart:math';

extension NsgDoubleExtension on double {
  double nsgRoundToDouble(int maxDecimalPlaces) {
    var m = pow(10, maxDecimalPlaces);
    return (m * this).roundToDouble() / m;
  }
}
