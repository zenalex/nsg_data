import '../nsg_data.dart';

class NsgDataField {
  //Имя колонки
  final String name;
  //Имя колонки для отображения пользователю
  String presentation = '';

  NsgDataField(this.name);
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  dynamic convertToJson(dynamic jsonValue) {
    return jsonValue;
  }

  dynamic get defaultValue => null;

  void setValue(NsgFieldValues fieldValues, dynamic value) {
    fieldValues.fields[name] = value;
    //Если поле есть в списке пустых полей (не запрошенных из БД), удалить его оттуда
    if (fieldValues.emptyFields.contains(name)) fieldValues.emptyFields.remove(name);
  }

  void setEmpty(NsgFieldValues fieldValues) {
    if (!fieldValues.emptyFields.contains(name)) fieldValues.emptyFields.add(name);
  }
}
