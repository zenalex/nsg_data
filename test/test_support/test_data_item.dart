import 'package:nsg_data/nsg_data.dart';

class TestDataItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameEnabled = 'enabled';

  @override
  String get typeName => 'TestDataItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
    addField(NsgDataBoolField(nameEnabled), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => TestDataItem();

  @override
  String get apiRequestItems => '/Data/TestDataItem';

  @override
  String get id => getFieldValue(nameId).toString();

  @override
  set id(String value) => setFieldValue(nameId, value);

  String get name => getFieldValue(nameName).toString();

  set name(String value) => setFieldValue(nameName, value);

  bool get enabled => getFieldValue(nameEnabled) as bool;

  set enabled(bool value) => setFieldValue(nameEnabled, value);
}

void ensureTestDataItemRegistered() {
  if (!NsgDataClient.client.isRegistered(TestDataItem)) {
    NsgDataClient.client.registerDataItem(TestDataItem());
  }
}

TestDataItem makeTestDataItem({
  required String id,
  required String name,
  bool enabled = false,
}) {
  ensureTestDataItemRegistered();
  final item = TestDataItem()
    ..id = id
    ..name = name
    ..enabled = enabled;
  return item;
}
