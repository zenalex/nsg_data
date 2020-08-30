class NsgDataField {
  final String name;

  NsgDataField(this.name);
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  dynamic get defaultValue => null;
}
