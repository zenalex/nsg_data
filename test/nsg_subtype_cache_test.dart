// Наследуемые типы кэшируются в чужое ведро (#1548).
//
// Ведро выбирается при ЗАПИСИ по фактическому типу объекта (addItemsToCache
// берёт items[0].runtimeType), а ссылка ЧИТАЕТ по объявленному — T из
// NsgDataReferenceField<T>. Пока это один тип, всё сходится; расходятся они
// там, где сервер вернул наследника (extensionTypeField) и _fromJsonList
// подменил объект.
//
// Цена промаха здесь не косметическая: «ремонт» в loadAllReferents идёт тем же
// путём и снова кладёт в ведро наследника, поэтому такие объекты не кэшируются
// вовсе и перезапрашиваются при каждом обращении.
//
// Ниже закреплены все три следствия из задачи плюс то, что фолбэк не ломает
// обычный случай и не путает сиблингов.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Базовый тип ссылки — аналог FileItem.
class ScFile extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'ScFile';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => ScFile();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

/// Наследник — аналог ImageFileItem, каким объект приезжает с сервера.
class ScImage extends ScFile {
  @override
  String get typeName => 'ScImage';

  @override
  NsgDataItem getNewObject() => ScImage();
}

/// Второй наследник — чтобы поймать, что фолбэк не хватает что попало.
class ScSvg extends ScFile {
  @override
  String get typeName => 'ScSvg';

  @override
  NsgDataItem getNewObject() => ScSvg();
}

/// Посторонний тип с тем же id — сиблинг, не наследник.
class ScAlien extends NsgDataItem {
  static const nameId = 'id';

  @override
  String get typeName => 'ScAlien';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
  }

  @override
  NsgDataItem getNewObject() => ScAlien();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

/// Владелец ссылки: поле объявлено на БАЗОВЫЙ тип — так же, как
/// `StadiumItem.photoId` объявлен ссылкой на `FileItem`.
class ScOwner extends NsgDataItem {
  static const nameId = 'id';
  static const nameFileId = 'fileId';

  @override
  String get typeName => 'ScOwner';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceField<ScFile>(nameFileId), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => ScOwner();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  ScFile get file => getReferent<ScFile>(nameFileId);
}

void main() {
  // Регистрация один раз: повторная зовёт initialize() и падает на добавлении
  // уже добавленного первичного ключа. Кэш между тестами не чистим — у каждого
  // теста свои id, так что пересечься им негде.
  setUpAll(() {
    NsgDataClient.client.registerDataItem(ScFile());
    NsgDataClient.client.registerDataItem(ScImage());
    NsgDataClient.client.registerDataItem(ScSvg());
    NsgDataClient.client.registerDataItem(ScAlien());
    NsgDataClient.client.registerDataItem(ScOwner());
  });

  ScOwner ownerPointingTo(String fileId) => ScOwner()
    ..id = 'owner-1'
    ..setFieldValue(ScOwner.nameFileId, fileId);

  test('следствие 1: объект приехал наследником — ссылка на базовый тип его находит', () {
    final image = ScImage()
      ..id = 'file-1'
      ..setFieldValue(ScFile.nameName, 'photo.png');
    // Ровно то, что делает _fromJsonList: подменил объект наследником и положил
    // пачку в ведро по фактическому типу.
    NsgDataClient.client.addItemsToCache(items: [image]);

    final found = ownerPointingTo('file-1').file;

    expect(found.id, 'file-1', reason: 'ссылка на ScFile обязана найти ScImage в его ведре');
    expect(identical(found, image), isTrue, reason: 'вернуться должен тот же экземпляр, а не копия');
  });

  test('следствие 2: пачка легла в ведро первого элемента — обычный элемент тоже находится', () {
    // Пачка начинается с наследника, значит ВСЯ она уедет в ведро ScImage,
    // включая обычный ScFile из середины.
    final image = ScImage()..id = 'file-2';
    final plain = ScFile()..id = 'file-3';
    NsgDataClient.client.addItemsToCache(items: [image, plain]);

    expect(ownerPointingTo('file-2').file.id, 'file-2');
    expect(ownerPointingTo('file-3').file.id, 'file-3', reason: 'обычный ScFile уехал в чужое ведро вместе с пачкой');
  });

  test('следствие 3: объект, положенный по объявленному типу, находится как и раньше', () {
    // Путь «референт из ведра ответа» кладёт по объявленному типу — фолбэк не
    // должен этот случай сломать, ведро T проверяется первым.
    final plain = ScFile()..id = 'file-4';
    NsgDataClient.client.addItemsToCache(items: [plain]);

    final found = ownerPointingTo('file-4').file;

    expect(identical(found, plain), isTrue);
  });

  test('ведро T имеет приоритет над ведром наследника при одинаковом id', () {
    final inBase = ScFile()..id = 'file-5';
    final inChild = ScImage()..id = 'file-5';
    NsgDataClient.client.addItemsToCache(items: [inChild]);
    NsgDataClient.client.addItemsToCache(items: [inBase]);

    expect(identical(ownerPointingTo('file-5').file, inBase), isTrue,
        reason: 'сначала своё ведро, наследники — только при промахе');
  });

  test('чужой тип с тем же id не подхватывается', () {
    NsgDataClient.client.addItemsToCache(items: [ScAlien()..id = 'file-6']);

    final found = ownerPointingTo('file-6');

    // Промах остаётся промахом: ScAlien не наследник ScFile, и подставлять его
    // нельзя — иначе фолбэк начнёт возвращать что попало.
    expect(found.getReferentOrNull<ScFile>(ScOwner.nameFileId), isNull);
  });

  test('второй наследник тоже находится', () {
    final svg = ScSvg()..id = 'file-7';
    NsgDataClient.client.addItemsToCache(items: [svg]);

    expect(identical(ownerPointingTo('file-7').file, svg), isTrue);
  });

  test('пустая ссылка остаётся пустой, а не ищется по вёдрам', () {
    expect(ownerPointingTo('').file.id, isEmpty);
  });
}
