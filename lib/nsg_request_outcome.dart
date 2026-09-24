import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Исход одного HTTP-запроса провайдера — для наблюдателя
/// [NsgRequestOutcome.observer].
///
/// ## Зачем (NSG-SOFT/futbolista-tasks#2279)
///
/// Приложению нужно знать «сервер сейчас отвечает» — индикатор «нет связи».
/// Узнать это ему было негде: каждый запрос создаёт свой `Dio`, общего
/// перехватчика нет, а `onRetry` приходит только на неудачах и только у тех
/// контроллеров, которым его передали. Из-за этого индикатор гасился в паре
/// мест на старте и горел красным посреди живого матча, пока события уходили.
///
/// Наблюдатель зовётся на КАЖДЫЙ запрос `baseRequestList`, `baseRequest` и
/// `imageRequest` — ответом ли, ошибкой ли. Контракт запросов не меняется:
/// исключения бросаются как раньше, а сбой самого наблюдателя проглатывается.
@immutable
class NsgRequestOutcome {
  const NsgRequestOutcome({
    required this.url,
    this.function,
    this.statusCode,
    this.errorType,
    this.error,
  });

  /// Наблюдатель исходов. По умолчанию не задан — пакет ведёт себя как раньше.
  static void Function(NsgRequestOutcome outcome)? observer;

  /// Адрес запроса БЕЗ строки запроса: в ней бывают параметры, которым не
  /// место в телеметрии.
  final String url;

  /// Имя функции, если вызывающий его передал.
  final String? function;

  /// HTTP-статус ответа. `null` — ответа не было вовсе (DNS, TLS, обрыв,
  /// таймаут).
  final int? statusCode;

  /// Тип ошибки dio, если запрос не удался.
  final DioExceptionType? errorType;

  /// Ошибка транспорта (текст), если ответа не было.
  final String? error;

  /// Сервер прислал ответ — какой угодно, хоть 4xx/5xx.
  bool get hasResponse => statusCode != null;

  /// Ответ пришёл от приложения за шлюзом: всё, кроме 5xx. 5xx — шлюз
  /// ответил, а приложение за ним нет; для человека это то же «нет связи».
  bool get serverReachable => statusCode != null && statusCode! < 500;

  /// Адрес без строки запроса и фрагмента.
  static String stripQuery(String? url) {
    if (url == null || url.isEmpty) return '';
    final cut = url.indexOf(RegExp(r'[?#]'));
    return cut < 0 ? url : url.substring(0, cut);
  }

  /// Отдать исход наблюдателю. Сбой наблюдателя запрос не ломает.
  static void notify({
    required String? url,
    String? function,
    int? statusCode,
    DioExceptionType? errorType,
    Object? error,
  }) {
    final observer = NsgRequestOutcome.observer;
    if (observer == null) return;
    try {
      observer(
        NsgRequestOutcome(
          url: stripQuery(url),
          function: function,
          statusCode: statusCode,
          errorType: errorType,
          error: error?.toString(),
        ),
      );
    } catch (e) {
      debugPrint('NsgRequestOutcome.observer failed: $e');
    }
  }

  /// Исход по исключению dio.
  static void notifyDio(DioException e, {required String? url, String? function}) {
    notify(
      url: url,
      function: function,
      statusCode: e.response?.statusCode,
      errorType: e.type,
      error: e.response == null ? (e.error ?? e.message) : null,
    );
  }
}
