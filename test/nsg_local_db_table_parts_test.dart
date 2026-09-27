import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class LocalScoreRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameCriterion = 'criterion';
  static const nameRating = 'rating';

  @override
  String get typeName => 'LocalScoreRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId));
    addField(NsgDataStringField(nameCriterion));
    addField(NsgDataDoubleField(nameRating));
  }

  @override
  NsgDataItem getNewObject() => LocalScoreRow();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);

  String get criterion => getFieldValue(nameCriterion).toString();
  set criterion(String value) => setFieldValue(nameCriterion, value);

  double get rating => getFieldValue(nameRating) as double;
  set rating(double value) => setFieldValue(nameRating, value);
}

class LocalScoreDoc extends NsgDataItem {
  static const nameId = 'id';
  static const nameRows = 'rows';

  @override
  String get typeName => 'LocalScoreDoc';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceListField<LocalScoreRow>(nameRows));
  }

  @override
  NsgDataItem getNewObject() => LocalScoreDoc();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<LocalScoreRow> get rows => NsgDataTable<LocalScoreRow>(owner: this, fieldName: nameRows);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local DB round-trip restores table row field values', () async {
    final temp = await Directory.systemTemp.createTemp('nsg-local-table-parts-');
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => temp.path,
    );

    final provider = NsgDataProvider(
      applicationName: 'local-table-test',
      firebaseToken: '',
      applicationVersion: '1',
      availableServers: NsgServerParams(<String, String>{}, ''),
    );
    for (final item in <NsgDataItem>[LocalScoreRow(), LocalScoreDoc()]) {
      if (!NsgDataClient.client.isRegistered(item.runtimeType)) {
        NsgDataClient.client.registerDataItem(item, remoteProvider: provider);
      }
    }

    await NsgLocalDb.instance.init('table-parts-${DateTime.now().microsecondsSinceEpoch}');
    final document = LocalScoreDoc()..id = 'document';
    document.rows.addRow(
      LocalScoreRow()
        ..id = 'speed'
        ..criterion = 'Скорость'
        ..rating = 4.5,
    );
    document.rows.addRow(
      LocalScoreRow()
        ..id = 'technique'
        ..criterion = 'Техника'
        ..rating = 3.25,
    );
    await NsgLocalDb.instance.postItems([document]);

    final params = NsgDataRequestParams()..compare.add(name: LocalScoreDoc.nameId, value: document.id);
    final restored = (await NsgLocalDb.instance.requestItems(LocalScoreDoc(), params)).single as LocalScoreDoc;

    expect(restored.rows.rows.map((row) => row.id), ['speed', 'technique']);
    expect(restored.rows.rows.map((row) => row.criterion), ['Скорость', 'Техника']);
    expect(restored.rows.rows.map((row) => row.rating), [4.5, 3.25]);
    expect(restored.rows.rows.every((row) => row.storageType == NsgDataStorageType.local), isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
  });
}
