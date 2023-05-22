import 'package:flutter/material.dart';
import 'package:nsg_controls/nsg_controls.dart';
import 'package:nsg_controls/widgets/nsg_error_widget.dart';

/// Вызов Future функции с прогресс индикатором и проверкой на ошибки
Future nsgFutureProgressAndException({required Function() func, String? text, BuildContext? context}) async {
  var progress = NsgProgressDialog(textDialog: text ?? 'Сохранение данных на сервер', context: context);
  try {
    progress.show();
    await func();
    progress.hide();
  } catch (ex) {
    progress.hide();
    await NsgErrorWidget.showError(ex as Exception);
  }
}
