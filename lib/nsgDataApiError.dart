import 'package:dio/dio.dart';

///Подробное описание ошибки связи с сервером
class NsgApiError {
  NsgApiError({this.code, this.message, this.errorType});

  ///Тип ошибки (из пакета Dio)
  final DioErrorType? errorType;

  ///Код ошибки. Основные коды:
  ///401 - отказано в доступе
  ///404 - вызываемая функция не найдена на сервере
  ///500 - сервер вернул ошибку. Подробности в message
  final int? code;

  ///Подробное описание ошибки. В случае ошибки 500 должна содержать информацию для отображения польщователю
  final String? message;
}
