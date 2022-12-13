import 'dart:math';
import 'package:intl/intl.dart';

extension NsgDoubleExtension on double {
  double nsgRoundToDouble(int maxDecimalPlaces) {
    var m = pow(10, maxDecimalPlaces);
    return (m * this).roundToDouble() / m;
  }

  String toStringFormatted({bool? showCents, bool? showRubles}) {
    NumberFormat formatter;
    String result;
    if (showCents == true) {
      formatter = NumberFormat("#,##0.00", "ru_RU");
    } else {
      formatter = NumberFormat("#,##0", "ru_RU");
    }
    if (showRubles == true) {
      result = formatter.format(this) + ' ₽';
    } else {
      result = formatter.format(this);
    }
    return result;
  }
}
