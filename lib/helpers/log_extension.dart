import 'package:flutter/material.dart';

extension NsgLogUtils on dynamic {
  void printError({String info = '', Function logFunction = printFunction}) =>
      // ignore: unnecessary_this
      logFunction('Error: ${this.runtimeType}', this, info, isError: true);

  void printInfo({String info = '', Function printFunction = printFunction}) =>
      // ignore: unnecessary_this
      printFunction('Info: ${this.runtimeType}', this, info);

  static void printFunction(
    String prefix,
    dynamic value,
    String info, {
    bool isError = false,
  }) {
    debugPrint('$prefix $value $info'.trim());
  }
}
