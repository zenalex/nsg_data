// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:nsg_data/nsgDataApiError.dart';

///Ошибка обмена данными с сервером
///
class NsgApiException implements Exception {
  final NsgApiError error;
  NsgApiException(this.error);

  ///Функция для отображения ошибок пользователю, используемая по-умолчанию. Задается в пакете nsg_controls
  ///Также, ее можно задать для каждого конкретного контроллера
  static void Function(BuildContext, NsgApiException)? showExceptionDefault;

  @override
  String toString() {
    return "${error.code} ||| ${error.message}";
  }
}
