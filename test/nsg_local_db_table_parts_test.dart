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

/// Имя класса не совпадает с `typeName`, как в веб-сборке, где
/// `runtimeType.toString()` минифицирован (`minified:a8y`). #4573.
class MinifiedNameRow extends NsgDataItem {
  static const nameId = 'id';
  static const nameNote = 'note';

  @override
  String get typeName => 'RenamedScoreRow';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId));
    addField(NsgDataStringField(nameNote));
  }

  @override
  NsgDataItem getNewObject() => MinifiedNameRow();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);

  String get note => getFieldValue(nameNote).toString();
  set note(String value) => setFieldValue(nameNote, value);
}

class MinifiedNameDoc extends NsgDataItem {
  static const nameId = 'id';
  static const nameRows = 'rows';

  @override
  String get typeName => 'RenamedScoreDoc';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceListField<MinifiedNameRow>(nameRows));
  }

  @override
  NsgDataItem getNewObject() => MinifiedNameDoc();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  NsgDataTable<MinifiedNameRow> get rows =>
      NsgDataTable<MinifiedNameRow>(owner: this, fieldName: nameRows);
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

  test(
    '#4573: table rows use the registered typeName, not the class name',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'nsg-local-table-renamed-',
      );
      const pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            pathProviderChannel,
            (_) async => temp.path,
          );
      final provider = NsgDataProvider(
        applicationName: 'local-table-renamed-test',
        firebaseToken: '',
        applicationVersion: '1',
        availableServers: NsgServerParams(<String, String>{}, ''),
      );
      for (final item in <NsgDataItem>[MinifiedNameRow(), MinifiedNameDoc()]) {
        if (!NsgDataClient.client.isRegistered(item.runtimeType)) {
          NsgDataClient.client.registerDataItem(item, remoteProvider: provider);
        }
      }
      // Тест — второй в файле: коллекция уже открыта первым, переоткрываем с
      // текущим набором типов, как это делает старт приложения.
      NsgLocalDb.initialized = false;
      await NsgLocalDb.instance.init(
        'table-renamed-${DateTime.now().microsecondsSinceEpoch}',
      );
      expect(
        NsgLocalDb.rowTableName(
          MinifiedNameDoc().getField(MinifiedNameDoc.nameRows)
              as NsgDataReferenceListField,
        ),
        'RenamedScoreRow',
      );

      final document = MinifiedNameDoc()..id = 'doc';
      document.rows.addRow(
        MinifiedNameRow()
          ..id = 'a'
          ..note = 'первая',
      );
      document.rows.addRow(
        MinifiedNameRow()
          ..id = 'b'
          ..note = 'вторая',
      );
      await NsgLocalDb.instance.postItems([document]);

      // Правка: одна строка ушла. Раньше удаление старых строк открывало бокс по
      // имени класса и падало «not in the known box names».
      final edited = MinifiedNameDoc()..id = 'doc';
      edited.rows.addRow(
        MinifiedNameRow()
          ..id = 'a'
          ..note = 'первая, правка',
      );
      await NsgLocalDb.instance.postItems([edited]);

      final params = NsgDataRequestParams()
        ..compare.add(name: MinifiedNameDoc.nameId, value: 'doc');
      final restored =
          (await NsgLocalDb.instance.requestItems(
                MinifiedNameDoc(),
                params,
              )).single
              as MinifiedNameDoc;
      expect(restored.rows.rows.map((row) => row.note), ['первая, правка']);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
    },
  );
}
