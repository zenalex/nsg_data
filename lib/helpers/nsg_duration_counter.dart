import 'package:flutter/material.dart';

class NsgDurationCounter {
  DateTime startTime = DateTime(0);
  DateTime prevTime = DateTime(0);
  NsgDurationCounter() {
    startTime = DateTime.now();
    prevTime = startTime;
  }

  void difPrev({String paramName = ''}) {
    var now = DateTime.now();
    debugPrint('$paramName = ${(now.difference(prevTime).inMilliseconds)} ms');
    prevTime = now;
  }

  ///Вывести разницу во времени от момента старта счетчика
  ///paramName - выводмое сообщение
  ///criticalDuration - если задано и время прошло больше этого значения, текст будет выведен желтым
  void difStart({String paramName = '', int criticalDuration = 0}) {
    var diff = DateTime.now().difference(startTime).inMilliseconds;
    if (criticalDuration > 0 && diff > criticalDuration) {
      printWarning('$paramName = ${(diff)} ms');
    } else {
      debugPrint('$paramName = ${(diff)} ms');
    }
  }
}

void printWarning(String text) {
  debugPrint('\x1B[33m$text\x1B[0m');
}

void printError(String text) {
  debugPrint('\x1B[31m$text\x1B[0m');
}
