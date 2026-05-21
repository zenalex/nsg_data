// ignore_for_file: file_names

import 'package:nsg_data/nsgDataApiError.dart';

///Ошибка обмена данными с сервером
///
class NsgApiException implements Exception {
  final NsgApiError error;
  NsgApiException(this.error);

  ///Функция для отображения ошибок пользователю, используемая по-умолчанию. Задается в пакете nsg_controls
  ///Также, ее можно задать для каждого конкретного контроллера
  static void Function(NsgApiException)? showExceptionDefault;

  /// `true`, если серверная ошибка — это бизнес-сообщение «нет прав на запись»,
  /// а не сбой инфраструктуры. Клиент-консьюмер (например, footballers_diary_app)
  /// может использовать этот геттер, чтобы не репортить такие ошибки как fatal в
  /// Sentry/GlitchTip, а показывать пользователю обычный snackbar.
  ///
  /// Сейчас детектируется по тексту сообщения сервера (`не хватает прав на запись`,
  /// англ. вариант `not enough rights to write`). Дополнено маркером кода 500 —
  /// 400/401/403 идут отдельной веткой и обычно уже не fatal.
  ///
  /// См. NSG-SOFT/futbolista-tasks#27.
  bool get isPermissionError {
    if (error.code != 500) return false;
    final msg = (error.message ?? '').toLowerCase();
    return msg.contains('не хватает прав на запись') ||
        msg.contains('не хватает прав') ||
        msg.contains('not enough rights to write') ||
        msg.contains('insufficient permissions');
  }

  @override
  String toString() {
    return "${error.code} ||| ${error.message}";
  }
}
