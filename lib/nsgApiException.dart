// ignore_for_file: file_names

import 'package:dio/dio.dart';
import 'package:nsg_data/nsgDataApiError.dart';

///Ошибка обмена данными с сервером
///
class NsgApiException implements Exception {
  final NsgApiError error;
  NsgApiException(this.error);

  ///Функция для отображения ошибок пользователю, используемая по-умолчанию. Задается в пакете nsg_controls
  ///Также, ее можно задать для каждого конкретного контроллера
  static void Function(NsgApiException)? showExceptionDefault;

  /// `true`, если серверная ошибка — это бизнес-ограничение прав на запись,
  /// а не сбой инфраструктуры. Предпочтительный способ проверки в коде —
  /// `e is NsgApiPermissionException` (subclass всегда переопределяет этот геттер).
  ///
  /// Базовая реализация покрывает два backward-compat случая:
  /// - HTTP 403 (каноничный код «нет прав» после серверного fix).
  /// - HTTP 500 + текстовый маркер прав (старый сервер до миграции).
  ///
  /// После полной миграции сервера на 403 оставить только проверку кода.
  ///
  /// См. NSG-SOFT/futbolista-tasks#27.
  bool get isPermissionError {
    if (error.code == 403) return true;
    if (error.code != 500) return false;
    final msg = (error.message ?? '').toLowerCase();
    return msg.contains('не хватает прав') ||
        msg.contains('not enough rights') ||
        msg.contains('insufficient permissions');
  }

  /// `true` если ошибка транспортная (обрыв соединения, таймаут) —
  /// в отличие от прикладной ошибки сервера (400/403/500).
  ///
  /// Позволяет отличить «нет интернета» от «сервер вернул ошибку»
  /// и показать соответствующее сообщение в UI.
  ///
  /// code == 1: connection error (SocketException, Connection reset by peer, …)
  /// code == 2: timeout (receiveTimeout / sendTimeout из DioExceptionType)
  ///
  /// См. NSG-SOFT/futbolista-tasks#407.
  bool get isNetworkError {
    if (error.code == 1 || error.code == 2) return true;
    final t = error.errorType;
    return t == DioExceptionType.connectionError ||
        t == DioExceptionType.connectionTimeout ||
        t == DioExceptionType.receiveTimeout ||
        t == DioExceptionType.sendTimeout;
  }

  @override
  String toString() {
    return "${error.code} ||| ${error.message}";
  }
}
