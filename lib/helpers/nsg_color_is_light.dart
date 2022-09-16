import 'package:flutter/material.dart';

abstract class NsgColor {
  /// Возвращает true, если цвет светлый, либо false, если тёмный
  static isLight(Color color) {
    if (color.computeLuminance() > 0.179) {
      return true;
    } else {
      return false;
    }
  }
}
