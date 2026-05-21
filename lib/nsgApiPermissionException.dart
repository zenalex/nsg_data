// ignore_for_file: file_names

import 'package:nsg_data/nsgApiException.dart';
import 'package:nsg_data/nsgDataApiError.dart';

/// Серверный отказ из-за недостатка прав на запись.
///
/// В отличие от [NsgApiException] с общим кодом 500, этот класс сигнализирует
/// о **бизнес-ограничении**, а не о сбое инфраструктуры. Клиент должен:
/// - показать пользователю [friendlyMessage] в виде snackbar/диалога;
/// - **не** репортить в Sentry/GlitchTip как fatal (фильтр в `_sentryBeforeSend`).
///
/// Источники:
/// - HTTP 403 — каноничный код «нет прав» (после серверного fix).
/// - HTTP 500 + тело начинается с маркера прав (backward compat до миграции).
///
/// См. NSG-SOFT/futbolista-tasks#27.
class NsgApiPermissionException extends NsgApiException {
  /// Читаемый текст от сервера: часть сообщения после маркера прав,
  /// либо полный body для ответов 403.
  final String friendlyMessage;

  NsgApiPermissionException({
    required NsgApiError error,
    required this.friendlyMessage,
  }) : super(error);

  /// Всегда `true` — этот класс семантически является permission-ошибкой.
  // ignore: annotate_overrides
  bool get isPermissionError => true;

  /// Возвращает [friendlyMessage] — чтобы `NsgErrorWidget.showError(ex)`
  /// показывал читаемый текст, а не технический "code ||| message".
  @override
  String toString() => friendlyMessage;
}
