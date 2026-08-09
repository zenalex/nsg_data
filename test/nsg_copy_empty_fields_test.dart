// Тесты копирования полей, которые НЕ читались из БД (#1394).
//
// Когда запрос сужен (neededFields), непрочитанные поля помечаются в объекте как
// пустые. Раньше copyFieldValues их всё равно копировал — то есть читал у источника
// defaultValue и записывал его в приёмник. Последствия были тихие и неприятные:
//  - клон узко прочитанного объекта выглядел полным и отдавал умолчания вместо
//    сигнала «поле не запрашивалось» (ни assert, ни телеметрия не срабатывали);
//  - слияние узко прочитанной версии в полную затирало нормальные значения нулями.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';

class CopyTestItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameCode = 'code';

  @override
  String get typeName => 'CopyTestItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
    addField(NsgDataIntField(nameCode), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => CopyTestItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

void main() {
  setUpAll(() {
    if (!NsgDataClient.client.isRegistered(CopyTestItem)) {
      NsgDataClient.client.registerDataItem(
        CopyTestItem(),
        remoteProvider: NsgDataProvider(
          applicationName: 'test',
          firebaseToken: '',
          applicationVersion: '1.0',
          availableServers: NsgServerParams(<String, String>{}, ''),
        ),
      );
    }
  });

  /// Объект, прочитанный узко: name прочитан, code — нет.
  CopyTestItem narrowSource() {
    final item = CopyTestItem()
      ..id = 'A'
      ..setFieldValue(CopyTestItem.nameName, 'Спартак');
    item.setFieldEmpty(CopyTestItem.nameCode);
    return item;
  }

  test('непрочитанное поле не копируется, признак переносится в приёмник', () {
    final target = CopyTestItem();
    target.copyFieldValues(narrowSource());

    expect(target.fieldValues.fields[CopyTestItem.nameName], 'Спартак');
    expect(target.fieldValues.fields.containsKey(CopyTestItem.nameCode), isFalse,
        reason: 'значения у непрочитанного поля нет, писать в приёмник нечего');
    expect(target.fieldValues.emptyFields, contains(CopyTestItem.nameCode),
        reason: 'приёмник обязан знать, что поле не запрашивалось, иначе промах не поймать');
  });

  test('слияние узкой версии не затирает уже прочитанное значение', () {
    final target = CopyTestItem()
      ..id = 'A'
      ..setFieldValue(CopyTestItem.nameCode, 42);

    target.copyFieldValues(narrowSource());

    expect(target.fieldValues.fields[CopyTestItem.nameCode], 42,
        reason: 'в источнике поле не читалось — это не повод обнулять то, что уже есть');
    expect(target.fieldValues.emptyFields, isNot(contains(CopyTestItem.nameCode)));
  });

  test('clone узкого объекта остаётся узким', () {
    final clone = narrowSource().clone() as CopyTestItem;

    expect(clone.fieldValues.fields.containsKey(CopyTestItem.nameCode), isFalse);
    expect(clone.fieldValues.emptyFields, contains(CopyTestItem.nameCode));
  });

  test('copyEmptyFields: false — признак не переносим, значение всё равно не трогаем', () {
    final target = CopyTestItem();
    target.copyFieldValues(narrowSource(), copyEmptyFields: false);

    expect(target.fieldValues.fields.containsKey(CopyTestItem.nameCode), isFalse);
    expect(target.fieldValues.emptyFields, isNot(contains(CopyTestItem.nameCode)));
  });

  test('прочитанные поля копируются как раньше', () {
    final source = CopyTestItem()
      ..id = 'B'
      ..setFieldValue(CopyTestItem.nameName, 'ЦСКА')
      ..setFieldValue(CopyTestItem.nameCode, 7);

    final target = CopyTestItem();
    target.copyFieldValues(source);

    expect(target.id, 'B');
    expect(target.fieldValues.fields[CopyTestItem.nameName], 'ЦСКА');
    expect(target.fieldValues.fields[CopyTestItem.nameCode], 7);
    expect(target.fieldValues.emptyFields, isEmpty);
  });
}
