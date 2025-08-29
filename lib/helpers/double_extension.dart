import 'dart:math';
import 'package:intl/intl.dart';

extension NsgDoubleExtension on double {
  double nsgRoundToDouble(int maxDecimalPlaces) {
    var m = pow(10, maxDecimalPlaces);
    return (m * this).roundToDouble() / m;
  }

  String toNumberFormat({bool? showHundredth, bool? showCurrencySymbol, String currencySymbol = '₽'}) {
    NumberFormat formatter;
    String result;
    if (showHundredth == true) {
      formatter = NumberFormat("#,##0.00", "ru_RU");
    } else {
      formatter = NumberFormat("#,##0", "ru_RU");
    }
    if (showCurrencySymbol == true) {
      result = '${formatter.format(this)} $currencySymbol';
    } else {
      result = formatter.format(this);
    }
    return result;
  }
}
