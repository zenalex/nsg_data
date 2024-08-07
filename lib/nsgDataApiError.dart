// ignore_for_file: file_names

import 'package:dio/dio.dart';

///Подробное описание ошибки связи с сервером
class NsgApiError {
  NsgApiError({this.code, this.message, this.errorType});

  ///Тип ошибки (из пакета Dio)
  final DioExceptionType? errorType;

  ///Код ошибки. Основные коды:
  ///400 - сервер вернул ошибку. Подробности в message. Повтор запроса смысла не имеет
  ///401 - отказано в доступе
  ///404 - вызываемая функция не найдена на сервере
  ///500 - сервер вернул ошибку. Подробности в message
  final int? code;

  ///Подробное описание ошибки. В случае ошибки 400 или 500 должна содержать информацию для отображения польщователю
  final String? message;
}
