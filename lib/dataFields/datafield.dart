class NsgDataField {
  final String name;

  NsgDataField(this.name);
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  dynamic convertToJson(dynamic jsonValue) {
    return jsonValue;
  }

  dynamic get defaultValue => null;
}
