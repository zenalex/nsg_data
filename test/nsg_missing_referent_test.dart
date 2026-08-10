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
}
