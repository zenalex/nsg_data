// Ненайденный референт (#1409).
//
// Ссылка задана, а объекта по ней в кэше нет — его не дочитали. Кэш в этом случае
// отдаёт новый пустой объект, экран рисует пустоту, и ошибки нигде нет: имя команды
// просто исчезает. Поймать это можно только там, где случается, то есть у пользователя.
//
// Проверка живёт в ветке промаха NsgDataReferenceField.getReferent, а не на каждом
// чтении поля. Здесь закрепляются оба свойства: промах сообщается, а удачное
// разрешение ссылки не сообщает ничего и возвращает тот же самый экземпляр из кэша.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class MrTeam extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'MrTeam';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => MrTeam();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class MrMatch extends NsgDataItem {
  static const nameId = 'id';
  static const nameTeamId = 'teamId';

  @override
  String get typeName => 'MrMatch';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceField<MrTeam>(nameTeamId), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => MrMatch();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  MrTeam get team => getReferent<MrTeam>(nameTeamId);
}

void main() {
  final reported = <String>[];

  setUpAll(() {
    NsgDataClient.client.registerDataItem(MrTeam());
    NsgDataClient.client.registerDataItem(MrMatch());
  });

  setUp(() {
    reported.clear();
    NsgFieldUsage.reset();
    NsgFieldUsage.onEmptyFieldAccess = (typeName, fieldName) => reported.add('$typeName.$fieldName');
  });

  tearDownAll(() {
    NsgFieldUsage.onEmptyFieldAccess = null;
    NsgFieldUsage.onEmptyFieldAccessWithOwner = null;
  });

  group('ненайденный референт', () {
    test('ссылка задана, объекта в кэше нет — сообщаем о промахе', () {
      var match = MrMatch();
      match.id = 'm1';
      match.setFieldValue(MrMatch.nameTeamId, 'team-которой-нет');

      var team = match.team;

      // Поведение прежнее: вызывающий получает пустышку, а не исключение.
      expect(team.isEmpty, isTrue);
      expect(reported, ['MrMatch.${MrMatch.nameTeamId}:referent']);
    });

    test('ссылка разрешилась — молчим и отдаём объект из кэша', () {
      var team = MrTeam();
      team.id = 'team-1';
      team.setFieldValue(MrTeam.nameName, 'Спартак');
      NsgDataClient.client.addItemsToCache(items: [team]);

      var match = MrMatch();
      match.id = 'm2';
      match.setFieldValue(MrMatch.nameTeamId, 'team-1');

      var resolved = match.team;

      expect(identical(resolved, team), isTrue, reason: 'должен вернуться тот же экземпляр из кэша');
      expect(resolved.getFieldValue(MrTeam.nameName), 'Спартак');
      expect(reported, isEmpty, reason: 'в удачном пути диагностика не должна стоить ничего');
    });

    test('ссылка не задана — это не промах', () {
      var match = MrMatch();
      match.id = 'm3';

      var team = match.team;

      expect(team.isEmpty, isTrue);
      expect(reported, isEmpty, reason: 'пустая ссылка — законное состояние, а не непрочитанные данные');
    });

    test('строгий режим роняет промах референта, как и промах поля', () {
      // Асимметрия, которую закрывает #1751: strictEmptyFields ронял только
      // чтение незапрошенного ПОЛЯ (nsg_data_item.dart, ветка emptyFields), а
      // промах референта проходил мимо. Между тем заметить его труднее: поле
      // хотя бы пустое, а здесь возвращается валидный с виду объект с нулевыми
      // полями, и экран молча рисует пустоту.
      NsgFieldUsage.strictEmptyFields = true;
      addTearDown(() => NsgFieldUsage.strictEmptyFields = false);

      var match = MrMatch();
      match.id = 'm6';
      match.setFieldValue(MrMatch.nameTeamId, 'нет-такого');

      expect(() => match.team, throwsA(isA<AssertionError>()),
          reason: 'в строгом режиме промах обязан падать, иначе флаг ничего не значит');
    });

    test('без строгого режима промах по-прежнему отдаёт пустышку', () {
      // Парная проверка: правка не должна превращать обычный debug-прогон в
      // падение. Строгость — opt-in, по умолчанию поведение прежнее.
      var match = MrMatch();
      match.id = 'm7';
      match.setFieldValue(MrMatch.nameTeamId, 'нет-и-тут');

      var team = match.team;

      expect(team.isEmpty, isTrue, reason: 'по умолчанию возвращается пустышка, как и раньше');
      expect(reported, isNotEmpty, reason: 'но отчёт о промахе остаётся');
    });

    test('об одном поле сообщаем один раз за сессию', () {
      var first = MrMatch();
      first.id = 'm4';
      first.setFieldValue(MrMatch.nameTeamId, 'нет-1');

      var second = MrMatch();
      second.id = 'm5';
      second.setFieldValue(MrMatch.nameTeamId, 'нет-2');

      first.team;
      second.team;
      first.team;

      expect(reported, hasLength(1), reason: 'дедупликация по паре тип.поле, иначе список из тысячи строк даст шторм');
    });
  });

  group('хук с объектом (NSG-SOFT/futbolista-tasks#1954)', () {
    // Приложение перепроверяет промах через паузу: гонку с ленивой дочиткой
    // чинить нельзя, пробел в наборе запроса — нужно. Зная только «тип.поле»,
    // перепроверить можно лишь обходом всего ведра кэша, а рядом всегда лежат
    // объекты, приехавшие референтом чужого запроса и не собирающиеся
    // резолвиться. С объектом перепроверка становится точечной.

    test('хук получает тот самый объект, у которого промахнулась ссылка', () {
      NsgDataItem? owner;
      NsgFieldUsage.onEmptyFieldAccessWithOwner = (typeName, fieldName, item) => owner = item;
      addTearDown(() => NsgFieldUsage.onEmptyFieldAccessWithOwner = null);

      var match = MrMatch();
      match.id = 'm10';
      match.setFieldValue(MrMatch.nameTeamId, 'нет-такой');

      match.team;

      expect(identical(owner, match), isTrue, reason: 'нужен именно этот экземпляр — по нему и перепроверяют ссылку');
    });

    test('той же ссылкой у того же объекта промах перепроверяется точечно', () {
      // Ровно то, ради чего хук и заведён: соседний объект с неразрешимой
      // ссылкой не мешает увидеть, что НАША ссылка разрешилась.
      NsgDataItem? owner;
      NsgFieldUsage.onEmptyFieldAccessWithOwner = (typeName, fieldName, item) => owner = item;
      addTearDown(() => NsgFieldUsage.onEmptyFieldAccessWithOwner = null);

      var noise = MrMatch();
      noise.id = 'm11-шум';
      noise.setFieldValue(MrMatch.nameTeamId, 'никогда-не-приедет');
      NsgDataClient.client.addItemsToCache(items: [noise]);

      var match = MrMatch();
      match.id = 'm11';
      match.setFieldValue(MrMatch.nameTeamId, 'приедет-позже');
      NsgDataClient.client.addItemsToCache(items: [match]);

      match.team;
      expect(owner, isNotNull);

      // «Дочитка приехала» — команда легла в кэш уже после промаха.
      var team = MrTeam();
      team.id = 'приедет-позже';
      NsgDataClient.client.addItemsToCache(items: [team]);

      final field = NsgDataClient.client.getFieldList(MrMatch).fields[MrMatch.nameTeamId] as NsgDataReferenceField;
      expect(field.getReferent(owner!, allowNull: true), isNotNull, reason: 'наша ссылка разрешилась — это гонка, а не пробел');
      expect(field.getReferent(noise, allowNull: true), isNull, reason: 'соседний объект так и не разрешился — и раньше он маскировал вывод');
    });

    test('старый хук не вызывается, когда задан новый', () {
      NsgFieldUsage.onEmptyFieldAccessWithOwner = (typeName, fieldName, item) {};
      addTearDown(() => NsgFieldUsage.onEmptyFieldAccessWithOwner = null);

      var match = MrMatch();
      match.id = 'm12';
      match.setFieldValue(MrMatch.nameTeamId, 'нет-такой');

      match.team;

      expect(reported, isEmpty, reason: 'два события на один промах — это дубль в трекере');
    });

    test('без нового хука поведение прежнее', () {
      // Совместимость: потребители пакета, которые про новый хук не знают,
      // продолжают получать ровно то же, что и раньше.
      var match = MrMatch();
      match.id = 'm13';
      match.setFieldValue(MrMatch.nameTeamId, 'нет-такой');

      match.team;

      expect(reported, ['MrMatch.${MrMatch.nameTeamId}:referent']);
    });

    test('дедупликация одна на оба хука', () {
      var seen = 0;
      NsgFieldUsage.onEmptyFieldAccessWithOwner = (typeName, fieldName, item) => seen++;
      addTearDown(() => NsgFieldUsage.onEmptyFieldAccessWithOwner = null);

      var first = MrMatch();
      first.id = 'm14';
      first.setFieldValue(MrMatch.nameTeamId, 'нет-1');
      var second = MrMatch();
      second.id = 'm15';
      second.setFieldValue(MrMatch.nameTeamId, 'нет-2');

      first.team;
      second.team;

      expect(seen, 1, reason: 'шторм из ListView.builder гасится там же, где и раньше');
    });
  });
}
