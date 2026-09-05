// Промах кэша ссылок отличим от незаполненной ссылки (NSG-SOFT/futbolista-tasks#1751).
//
// `getReferent` на промахе отдаёт пустышку, и она неотличима от честного «ссылка
// не заполнена». Здесь закрепляются две вещи:
//
// 1. правило различения (`nsgReferenceIsSet`, `nsgReferentStateOf`) — чистое, на
//    строках, читается без знания кэша;
// 2. дыра, которой не было у типизированной ссылки: `NsgDataUntypedReferenceField`
//    на промахе не сообщал НИЧЕГО. Группа «нетипизированная ссылка» показывает
//    старое поведение и новое на одном и том же объекте.
//
// Соседний `nsg_missing_referent_test.dart` держит саму отчётность типизированной
// ссылки; здесь она не дублируется.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class RsTeam extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'RsTeam';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => RsTeam();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class RsMatch extends NsgDataItem {
  static const nameId = 'id';
  static const nameTeamId = 'teamId';
  static const nameSubjectId = 'subjectId';

  @override
  String get typeName => 'RsMatch';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceField<RsTeam>(nameTeamId), primaryKey: false);
    // Нетипизированная ссылка: значение приезжает как `{guid}.{ТипОбъекта}`.
    addField(NsgDataUntypedReferenceField(nameSubjectId, defaultReferentType: RsTeam), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => RsMatch();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  RsTeam get team => getReferent<RsTeam>(nameTeamId);
  NsgDataItem get subject => getReferent<NsgDataItem>(nameSubjectId);
}

void main() {
  const emptyGuid = '00000000-0000-0000-0000-000000000000';

  final reported = <String>[];

  setUpAll(() {
    NsgDataClient.client.registerDataItem(RsTeam());
    NsgDataClient.client.registerDataItem(RsMatch());
  });

  setUp(() {
    reported.clear();
    NsgFieldUsage.reset();
    NsgFieldUsage.onEmptyFieldAccess = (typeName, fieldName) => reported.add('$typeName.$fieldName');
  });

  tearDownAll(() {
    NsgFieldUsage.onEmptyFieldAccess = null;
  });

  RsTeam cachedTeam(String id) {
    var team = RsTeam();
    team.id = id;
    team.setFieldValue(RsTeam.nameName, 'Спартак');
    NsgDataClient.client.addItemsToCache(items: [team]);
    return team;
  }

  group('nsgReferenceIsSet — заполнена ли ссылка (решение по строке)', () {
    test('guid и guid с суффиксом типа — заполнена', () {
      expect(nsgReferenceIsSet('team-1'), isTrue);
      expect(nsgReferenceIsSet('team-1.RsTeam'), isTrue);
    });

    test('все формы «пусто»', () {
      // Сервер кладёт то один вариант, то другой — поэтому проверяются все.
      expect(nsgReferenceIsSet(''), isFalse);
      expect(nsgReferenceIsSet('   '), isFalse);
      expect(nsgReferenceIsSet(emptyGuid), isFalse);
      expect(nsgReferenceIsSet('$emptyGuid.RsTeam'), isFalse);
      expect(nsgReferenceIsSet('.RsTeam'), isFalse);
    });

    test('регистр букв не важен, а не-нулевой guid с нулевым не путается', () {
      expect(nsgReferenceIsSet(emptyGuid.toUpperCase()), isFalse);
      expect(nsgReferenceIsSet('0000000A-0000-0000-0000-000000000000'), isTrue);
    });
  });

  group('nsgReferentStateOf — три состояния из двух фактов', () {
    test('ссылка не заполнена — notSet, и объект тут ни при чём', () {
      // referentResolved: true — так ведёт себя нетипизированная ссылка с нулевым
      // guid: она отдаёт новый объект даже с allowNull.
      expect(nsgReferentStateOf(rawReference: '', referentResolved: false), NsgReferentState.notSet);
      expect(nsgReferentStateOf(rawReference: emptyGuid, referentResolved: true), NsgReferentState.notSet);
    });

    test('ссылка заполнена, объекта нет — missing, а НЕ notSet', () {
      // Вся задача — в этой строке. До неё оба состояния приходили к вызывающему
      // одинаковой пустышкой.
      expect(nsgReferentStateOf(rawReference: 'team-1', referentResolved: false), NsgReferentState.missing);
    });

    test('ссылка заполнена, объект дочитан — loaded', () {
      expect(nsgReferentStateOf(rawReference: 'team-1', referentResolved: true), NsgReferentState.loaded);
    });
  });

  group('referentState на живом объекте', () {
    test('промах и незаполненная ссылка дают ОДНУ И ТУ ЖЕ пустышку', () {
      var missed = RsMatch();
      missed.id = 'm1';
      missed.setFieldValue(RsMatch.nameTeamId, 'нет-такой-команды');

      var blank = RsMatch();
      blank.id = 'm2';

      // Вот из-за чего ошибка всплывает далеко от места: по объекту эти два
      // матча неотличимы, хотя у одного команда есть, а у другого нет.
      expect(missed.team.isEmpty, isTrue);
      expect(blank.team.isEmpty, isTrue);
      expect(missed.team == blank.team, isTrue, reason: 'две пустышки одного типа равны');

      // Правило их различает.
      expect(missed.referentState(RsMatch.nameTeamId), NsgReferentState.missing);
      expect(blank.referentState(RsMatch.nameTeamId), NsgReferentState.notSet);
    });

    test('сравнение по объекту врёт там, где по ссылке всё совпадает', () {
      // Объект команды существует, но выборка его не дочитала: в кэше его нет.
      var team = RsTeam();
      team.id = 'team-7';

      var match = RsMatch();
      match.id = 'm3';
      match.setFieldValue(RsMatch.nameTeamId, 'team-7');

      expect(match.team == team, isFalse, reason: 'ровно этот false и уводил код в ветку «нет данных»');
      expect(match.getFieldValue(RsMatch.nameTeamId), team.id, reason: 'а по строке-ссылке команда та же');
      expect(match.referentState(RsMatch.nameTeamId), NsgReferentState.missing);
    });

    test('дочитанная ссылка — loaded, и referentState молчит', () {
      var team = cachedTeam('team-1');
      var match = RsMatch();
      match.id = 'm4';
      match.setFieldValue(RsMatch.nameTeamId, 'team-1');

      expect(match.referentState(RsMatch.nameTeamId), NsgReferentState.loaded);
      expect(identical(match.referentIfLoaded<RsTeam>(RsMatch.nameTeamId), team), isTrue);
      expect(reported, isEmpty, reason: 'referentState читает кэш с allowNull и сам не сообщает ничего');
    });

    test('referentState не создаёт пустышку и не тратит слот дедупликации', () {
      var match = RsMatch();
      match.id = 'm5';
      match.setFieldValue(RsMatch.nameTeamId, 'нет-1');

      expect(match.referentState(RsMatch.nameTeamId), NsgReferentState.missing);
      expect(reported, isEmpty, reason: 'проверка состояния — не чтение данных');

      // Слот остался за настоящим читателем.
      match.team;
      expect(reported, ['RsMatch.${RsMatch.nameTeamId}:referent']);
    });
  });

  group('нетипизированная ссылка: раньше промах не оставлял следа', () {
    test('старый путь молчал, новый — называет промах', () {
      var match = RsMatch();
      match.id = 'm6';
      match.setFieldValue(RsMatch.nameSubjectId, 'нет-такого.RsTeam');

      // Так это читалось: пустышка. Теперь вместе с ней уходит и сообщение —
      // до правки здесь не было ни лога в debug, ни события в релизе, потому что
      // getItemsFromCache(allowNull: false) отдавал getNewObject напрямую.
      expect(match.subject.isEmpty, isTrue, reason: 'поведение прежнее: пустышка, а не исключение');
      expect(reported, ['RsMatch.${RsMatch.nameSubjectId}:referent']);
    });

    test('состояние различимо так же, как у типизированной', () {
      var missed = RsMatch();
      missed.id = 'm7';
      missed.setFieldValue(RsMatch.nameSubjectId, 'нет-и-тут.RsTeam');
      expect(missed.referentState(RsMatch.nameSubjectId), NsgReferentState.missing);
      expect(missed.referentIfLoaded<RsTeam>(RsMatch.nameSubjectId), isNull);

      var blank = RsMatch();
      blank.id = 'm8';
      expect(blank.referentState(RsMatch.nameSubjectId), NsgReferentState.notSet);

      var zero = RsMatch();
      zero.id = 'm9';
      zero.setFieldValue(RsMatch.nameSubjectId, '$emptyGuid.RsTeam');
      expect(zero.referentState(RsMatch.nameSubjectId), NsgReferentState.notSet,
          reason: 'нулевой guid — это «не заполнено», хотя объект при этом возвращается');
    });

    test('дочитанный объект отдаётся, чужой тип — null без крика о промахе', () {
      var team = cachedTeam('team-2');
      var match = RsMatch();
      match.id = 'm10';
      match.setFieldValue(RsMatch.nameSubjectId, 'team-2.RsTeam');

      expect(match.referentState(RsMatch.nameSubjectId), NsgReferentState.loaded);
      expect(identical(match.referentIfLoaded<RsTeam>(RsMatch.nameSubjectId), team), isTrue);
      // Ссылка может законно указывать на другой тип. Это не промах: объект
      // дочитан, просто он не тот, который спросили.
      expect(match.referentIfLoaded<RsMatch>(RsMatch.nameSubjectId), isNull);
      expect(reported, isEmpty);
    });

    test('вызывающий с allowNull по-прежнему не порождает сообщений', () {
      // Гарантия из #1547: кэш с allowNull щупает сам загрузчик, и его проба не
      // должна съедать слот дедупликации у настоящего промаха экрана.
      var match = RsMatch();
      match.id = 'm11';
      match.setFieldValue(RsMatch.nameSubjectId, 'нет-совсем.RsTeam');

      expect(match.getReferentOrNull<NsgDataItem>(RsMatch.nameSubjectId), isNull);
      expect(reported, isEmpty);
    });

    test('строгий режим роняет и промах нетипизированной ссылки', () {
      NsgFieldUsage.strictEmptyFields = true;
      addTearDown(() => NsgFieldUsage.strictEmptyFields = false);

      var match = RsMatch();
      match.id = 'm12';
      match.setFieldValue(RsMatch.nameSubjectId, 'нет-строго.RsTeam');

      expect(() => match.subject, throwsA(isA<AssertionError>()));
    });
  });

  group('referentIfLoaded — промах виден в диагностике', () {
    test('называет тип и поле с меткой :referent', () {
      var match = RsMatch();
      match.id = 'm13';
      match.setFieldValue(RsMatch.nameTeamId, 'нет-2');

      expect(match.referentIfLoaded<RsTeam>(RsMatch.nameTeamId), isNull);
      expect(reported, ['RsMatch.${RsMatch.nameTeamId}:referent']);
    });

    test('незаполненная ссылка в диагностику не идёт', () {
      var match = RsMatch();
      match.id = 'm14';

      expect(match.referentIfLoaded<RsTeam>(RsMatch.nameTeamId), isNull);
      expect(reported, isEmpty, reason: 'пустая ссылка — законное состояние, а не непрочитанные данные');
    });
  });
}
