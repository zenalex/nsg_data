import 'package:flutter/material.dart';
import 'package:nsg_controls/nsg_controls.dart';
import 'package:nsg_controls/widgets/nsg_error_widget.dart';

/// Вызов Future функции с прогресс индикатором и проверкой на ошибки
Future nsgFutureProgressAndException({required Function() func, String? text, BuildContext? context, bool showProgress = true}) async {
  var progress = NsgProgressDialog(textDialog: text ?? '', context: context);
  try {
    if (showProgress) {
      progress.show();
    }
    await func();
    if (showProgress) {
      progress.hide();
    }
  } on Exception catch (ex) {
    if (showProgress) {
      progress.hide();
    }
    await NsgErrorWidget.showError(ex);
  }
}
