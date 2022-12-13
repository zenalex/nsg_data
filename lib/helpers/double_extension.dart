import 'dart:math';
import 'package:intl/intl.dart';

extension NsgDoubleExtension on double {
  double nsgRoundToDouble(int maxDecimalPlaces) {
    var m = pow(10, maxDecimalPlaces);
    return (m * this).roundToDouble() / m;
  }

  String toStringFormatted({bool? showCents}) {
    if (showCents) {
      var formatter = NumberFormat("#,##0.00", "ru_RU");
    } else {
      var formatter = NumberFormat("#,##0", "ru_RU");
    }
    return formatter.format(this);
  }
}
