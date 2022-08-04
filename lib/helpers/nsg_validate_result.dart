///Результат валидации полей объекта перед сохранением
class NsgValidateResult {
  ///Валидация рпройдена успешно (Да/Нет)
  bool isValid = true;

  ///Map полей с ошибками - имя поля - текст ошибки
  Map<String, String> fieldsWithError = {};

  ///Дополнительный текст ошибки, не связанный с конкретным полем
  String errorMessage = '';
}
