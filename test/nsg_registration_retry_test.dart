import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class RegistrationRetryItem extends NsgDataItem {
  RegistrationRetryItem({this.failInitialization = false});
  final bool failInitialization;

  @override
  String get typeName => 'RegistrationRetryItem';

  @override
  void initialize() {
    addField(NsgDataStringField('id'), primaryKey: true);
    if (failInitialization) throw StateError('Initialization interrupted');
    addField(NsgDataStringField('name'));
  }

  @override
  NsgDataItem getNewObject() => RegistrationRetryItem();
}

void main() {
  test('startup registration can repeat after a failed connection', () {
    final client = NsgDataClient.client;
    final first = RegistrationRetryItem();
    client.registerDataItem(first);
    first.paramList.params['customSetting'] = 'preserved';
    first['name'] = 'existing value';

    for (var attempt = 0; attempt < 3; attempt++) {
      final replacement = RegistrationRetryItem();
      client.registerDataItem(replacement);
      expect(replacement.primaryKeyField, 'id');
      expect(replacement.fieldList.fields.keys, unorderedEquals(['id', 'name']));
      expect(replacement.paramList.params['customSetting'], 'preserved');
      expect(first['name'], 'existing value');
    }
  });

  test('registration retries after initialization stopped after the key', () {
    final client = NsgDataClient.client;
    expect(() => client.registerDataItem(RegistrationRetryItem(failInitialization: true)), throwsStateError);
    final replacement = RegistrationRetryItem();
    client.registerDataItem(replacement);
    expect(replacement.primaryKeyField, 'id');
    expect(replacement.fieldList.fields.keys, unorderedEquals(['id', 'name']));
  });
}
