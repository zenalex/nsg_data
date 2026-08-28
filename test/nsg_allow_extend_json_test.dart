// Симметрия toJson/fromJson у расширяемых типов (allowExtend).
//
// `_toJsonBody` писал поле дополнительных свойств обычной строкой — то есть
// незаполненное поле уезжало как `""`. А `fromJson` делал над ним БЕЗУСЛОВНЫЙ
// `jsonDecode`, и `jsonDecode('')` — это `FormatException`. С сервера так
// никогда не приходит: он отдаёт поле либо валидным документом, либо не отдаёт
// вовсе. Дефект вылезал только когда объект сериализуют сами и скармливают
// свой же вывод обратно — локальная БД, клиентские снимки.
//
// Наружу это вышло на снимке дашборда (zenalex/footballers_diary_app#655):
// `allowExtend` у `FileItem`, то есть у логотипов команд, а они в снимке есть
// всегда — разваливался каждый снимок, молча.
//
// ⚠️ В наивном тесте дефект НЕ воспроизводится: `toJson` пишет только те поля,
// которые кто-то заполнил, а в свежесозданном объекте ключа просто нет.
// Поэтому здесь поле выставляется ЯВНО — ровно так его отдаёт сервер.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class ExtendTestItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameNickname = 'nickname';
  static const nameAdditionalProperties = 'additionalProperties';
  static const nameExtensionType = 'extensionType';

  @override
  String get typeName => 'ExtendTestItem';

  @override
  bool get allowExtend => true;

  @override
  String get additionalDataField => nameAdditionalProperties;

  @override
  String get extensionTypeField => nameExtensionType;

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
    addField(NsgDataStringField(nameNickname), primaryKey: false);
    addField(NsgDataStringField(nameAdditionalProperties), primaryKey: false);
    addField(NsgDataStringField(nameExtensionType), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => ExtendTestItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  String get name => getFieldValue(nameName).toString();
  set name(String value) => setFieldValue(nameName, value);

  String get nickname => getFieldValue(nameNickname).toString();

  String get additionalProperties => getFieldValue(nameAdditionalProperties).toString();
  set additionalProperties(String value) => setFieldValue(nameAdditionalProperties, value);
}

/// Обычный тип, у которого расширения нет вовсе: правка не должна его задеть.
class PlainTestItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'PlainTestItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => PlainTestItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

const _id = 'd6b7a0f4-0000-0000-0000-000000000042';

ExtendTestItem _newItem() => ExtendTestItem()
  ..id = _id
  ..name = 'Спартак';

void main() {
  setUpAll(() {
    final provider = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '1.0',
      availableServers: NsgServerParams(<String, String>{}, ''),
    );
    if (!NsgDataClient.client.isRegistered(ExtendTestItem)) {
      NsgDataClient.client.registerDataItem(ExtendTestItem(), remoteProvider: provider);
    }
    if (!NsgDataClient.client.isRegistered(PlainTestItem)) {
      NsgDataClient.client.registerDataItem(PlainTestItem(), remoteProvider: provider);
    }
  });

  group('запись', () {
    test('незаполненное поле дополнительных свойств в JSON не пишется', () {
      final item = _newItem()..additionalProperties = '';

      final json = item.toJson();

      expect(json.containsKey(ExtendTestItem.nameAdditionalProperties), isFalse,
          reason: 'пустая строка здесь не «пустой документ», а невалидный JSON');
      expect(json[ExtendTestItem.nameName], 'Спартак', reason: 'остальные поля писаться не перестали');
    });

    test('заполненное поле дополнительных свойств пишется как есть', () {
      final item = _newItem()..additionalProperties = '{"nickname":"Мясо"}';

      final json = item.toJson();

      expect(json[ExtendTestItem.nameAdditionalProperties], '{"nickname":"Мясо"}');
    });

    test('поле из одних пробелов тоже не пишется', () {
      final item = _newItem()..additionalProperties = '   ';

      expect(item.toJson().containsKey(ExtendTestItem.nameAdditionalProperties), isFalse);
    });
  });

  group('чтение', () {
    test('свой же вывод читается обратно — тот самый объект, а не соседний', () {
      // ⚠️ Поле выставляется явно: без этого ключа в toJson не будет вовсе и
      // дефект не воспроизведётся.
      final source = _newItem()..additionalProperties = '';

      final restored = ExtendTestItem()..fromJson(source.toJson());

      // Смотрим на САМ пострадавший объект: до фикса fromJson бросал
      // FormatException и объект не читался целиком.
      expect(restored.id, _id);
      expect(restored.name, 'Спартак');
    });

    test('старая запись с пустой строкой читается, а не падает', () {
      // Снимки и локальная БД, записанные до фикса, уже содержат `""`.
      final item = ExtendTestItem();

      expect(
          () => item.fromJson({
                ExtendTestItem.nameId: _id,
                ExtendTestItem.nameName: 'Спартак',
                ExtendTestItem.nameAdditionalProperties: '',
              }),
          returnsNormally);
      expect(item.name, 'Спартак');
    });

    test('заполненные дополнительные свойства по-прежнему разбираются', () {
      final item = ExtendTestItem()
        ..fromJson({
          ExtendTestItem.nameId: _id,
          ExtendTestItem.nameName: 'Спартак',
          ExtendTestItem.nameAdditionalProperties: jsonEncode({'nickname': 'Мясо'}),
        });

      expect(item.nickname, 'Мясо', reason: 'фикс не должен отключить сам механизм расширения');
    });

    test('битое значение стоит дополнительных полей, а не всего объекта', () {
      final item = ExtendTestItem()
        ..fromJson({
          ExtendTestItem.nameId: _id,
          ExtendTestItem.nameName: 'Спартак',
          ExtendTestItem.nameAdditionalProperties: '{это не json',
        });

      // Гашение поштучное, на объекте: сам объект прочитан.
      expect(item.id, _id);
      expect(item.name, 'Спартак');
      expect(item.nickname, '', reason: 'из нечитаемого документа брать нечего');
    });

    test('не-объект в поле дополнительных свойств объект не роняет', () {
      final item = ExtendTestItem()
        ..fromJson({
          ExtendTestItem.nameId: _id,
          ExtendTestItem.nameName: 'Спартак',
          ExtendTestItem.nameAdditionalProperties: '42',
        });

      expect(item.name, 'Спартак');
    });
  });

  test('обычный тип round-trip переживает', () {
    final source = PlainTestItem()
      ..id = _id
      ..setFieldValue(PlainTestItem.nameName, 'Зенит');

    final restored = PlainTestItem()..fromJson(source.toJson());

    expect(restored.id, _id);
    expect(restored.getFieldValue(PlainTestItem.nameName), 'Зенит');
  });
}
