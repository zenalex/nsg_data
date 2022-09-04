///Результат валидации полей объекта перед сохранением
class NsgValidateResult {
  ///Валидация рпройдена успешно (Да/Нет)
  bool isValid = true;

  ///Map полей с ошибками - имя поля - текст ошибки
  Map<String, String> fieldsWithError = {};

  ///Дополнительный текст ошибки, не связанный с конкретным полем
  String errorMessage = '';
  String errorMessageWithFields() {
    var s = 'Обнаружены следующие ошибки:';
    if (errorMessage.isNotEmpty) {
      s += '\n$errorMessage';
    }
    for (var value in fieldsWithError.values) {
      s += '\n$value';
    }
    return s;
  }
}
