import 'dart:math';
import 'package:intl/intl.dart';

extension NsgDoubleExtension on double {
  double nsgRoundToDouble(int maxDecimalPlaces) {
    var m = pow(10, maxDecimalPlaces);
    return (m * this).roundToDouble() / m;
  }

  String toStringFormatted() {
    var formatter = NumberFormat("#,###,000", "ru_RU");
    return formatter.format(this);
  }
}
