// Трейл «кто грузил объект» в событии `nsg: read of unrequested field`.
//
// Запись трейла — единственное, что делает промах дочитывания адресуемым: она
// говорит, какой запрос грузил объект и с каким набором ссылок. Чинится промах
// сверкой двух списков, поэтому у записи есть требование, которого нет у
// обычного лога: обрезанный список НЕЛЬЗЯ прочитать как полный. Иначе вывод
// «поля в запросе нет» оказывается артефактом среза — так уже закрыли две
// задачи с неверным корнем.
//
// Здесь закрепляются свойства записи (полнота, честная обрезка по границе поля
// со счётчиком) и свойства буфера (один экземпляр на одинаковую запись,
// глубина).

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Набор из [count] полей вида `field000`, `field001`, ...
List<String> _fields(int count) => List<String>.generate(count, (i) => 'field${i.toString().padLeft(3, '0')}');

/// Список ссылок из записи трейла: то, что между `[ref: ` и `]`.
String _refsOf(String entry) {
  final start = entry.indexOf('[ref: ') + '[ref: '.length;
  return entry.substring(start, entry.length - 1);
}

void main() {
  setUp(NsgFieldUsage.reset);
  tearDown(NsgFieldUsage.reset);

  test('набор, влезающий в лимит, попадает в трейл целиком', () {
    final references = _fields(20); // 20 × 9 символов --> 179 с запятыми
    NsgFieldUsage.noteRequest('MatchItem', 'https://data1.futbolista.me/Api/MatchItem', references);

    final entry = NsgFieldUsage.recentRequests.single;
    expect(entry, 'MatchItem /Api/MatchItem [ref: ${references.join(',')}]');
    expect(entry.contains('…'), isFalse);
  });

  test('пустой набор помечается прочерком', () {
    NsgFieldUsage.noteRequest('SeriesStats', 'https://data1.futbolista.me/Api/SeriesStats', const []);
    NsgFieldUsage.noteRequest('TariffGroup', 'https://data1.futbolista.me/Api/TariffGroup', null);

    expect(NsgFieldUsage.recentRequests, ['SeriesStats /Api/SeriesStats [ref: —]', 'TariffGroup /Api/TariffGroup [ref: —]']);
  });

  test('самый длинный реальный набор модели (654 символа) не режется', () {
    // addAllReferences(MatchItem) на замере 20.08.2026: 40 полей, 654 символа.
    // Это верхняя граница того, что встречается в живых событиях, — она обязана
    // проходить целиком, иначе замер сделан зря.
    final references = <String>[
      'userId', 'recordKeeperId', 'ruleSetId', 'teamHomeId', 'teamAwayId', 'winnerId', 'winnerTournamentTeamId',
      'stadiumId', 'tournamentGroupId', 'tournamentStageId', 'tournamentId', 'lastEventId', 'liveStreamId',
      'liveStreamVKId', 'liveStreamYTId', 'approvedByHomeTeamAdminId', 'approvedByAwayTeamAdminId', 'originalId',
      'playerStatsId', 'teamStatsId', 'teamHomeMovementRuleId', 'teamAwayMovementRuleId', 'tournamentTeamHomeId',
      'tournamentTeamAwayId', 'matchCheckListId', 'tablePenaltyShootOut', 'tablePenaltyShootOut.teamId',
      'tablePenaltyShootOut.playerId', 'trackedPlayers', 'trackedPlayers.playerId', 'trackedPlayers.teamId',
      'matchLinks', 'matchLinks.socialId', 'files', 'files.photoId', 'stats', 'stats.teamId', 'referees',
      'referees.refereeId', 'referees.refereeRoleId',
    ];
    expect(references.join(',').length, 654, reason: 'набор из замера изменился — перепроверить requestRefsLimit');

    NsgFieldUsage.noteRequest('MatchItem', 'https://data1.futbolista.me/Api/MatchItem', references);

    expect(_refsOf(NsgFieldUsage.recentRequests.single), references.join(','));
  });

  test('набор сверх лимита режется по границе поля и говорит, сколько полей не поместилось', () {
    final references = _fields(200); // 200 × 9 --> 1999 символов, лимит 800
    NsgFieldUsage.noteRequest('FilterItem', 'https://data1.futbolista.me/Api/FilterItem', references);

    final refs = _refsOf(NsgFieldUsage.recentRequests.single);
    final parts = refs.split(',');
    final counter = parts.removeLast();

    // Счётчик — не украшение: он превращает «поля нет» в «неизвестно».
    expect(counter, '…+${references.length - parts.length}');
    // Ни одного обрубленного имени: каждое поле либо целиком, либо его нет.
    expect(parts, references.take(parts.length));
    expect(parts.length, lessThan(references.length));
    // Лимит соблюдён по самому списку; счётчик — служебный хвост поверх него.
    expect(parts.join(',').length, lessThanOrEqualTo(NsgFieldUsage.requestRefsLimit));
    expect(refs.length, greaterThan(NsgFieldUsage.requestRefsLimit - 20));
  });

  test('одно поле длиннее лимита всё равно попадает в запись', () {
    final monster = List<String>.filled(120, 'table').join('.'); // 719 символов, но одно поле
    NsgFieldUsage.noteRequest('Weird', 'https://data1.futbolista.me/Api/Weird', [monster, 'photoId']);

    final refs = _refsOf(NsgFieldUsage.recentRequests.single);
    expect(refs, startsWith(monster));
  });

  test('повтор запроса не занимает второй слот и переезжает в конец', () {
    // Подряд — это ретраи одного запроса (RetryOptions.retry до autoRepeateCount).
    NsgFieldUsage.noteRequest('TeamItem', '/Api/TeamItem', const ['photoId']);
    NsgFieldUsage.noteRequest('TeamItem', '/Api/TeamItem', const ['photoId']);
    // Вразбивку — это перечитывание по кругу на живом экране.
    NsgFieldUsage.noteRequest('UserItem', '/Api/UserItem', const ['photoId']);
    NsgFieldUsage.noteRequest('TeamItem', '/Api/TeamItem', const ['photoId']);

    expect(NsgFieldUsage.recentRequests, ['UserItem /Api/UserItem [ref: photoId]', 'TeamItem /Api/TeamItem [ref: photoId]']);
  });

  test('разные наборы одного типа живут в буфере по отдельности', () {
    NsgFieldUsage.noteRequest('MatchItem', '/Api/MatchItem', const ['teamHomeId.photoId']);
    NsgFieldUsage.noteRequest('MatchItem', '/Api/MatchItem', const ['tournamentId']);

    expect(NsgFieldUsage.recentRequests, [
      'MatchItem /Api/MatchItem [ref: teamHomeId.photoId]',
      'MatchItem /Api/MatchItem [ref: tournamentId]',
    ]);
  });

  test('буфер не глубже recentRequestsLimit, вытесняются самые старые', () {
    for (var i = 0; i < NsgFieldUsage.recentRequestsLimit + 5; i++) {
      NsgFieldUsage.noteRequest('Type$i', '/Api/Type$i', ['field$i']);
    }

    final requests = NsgFieldUsage.recentRequests;
    expect(requests.length, NsgFieldUsage.recentRequestsLimit);
    expect(requests.first, startsWith('Type5 '));
    expect(requests.last, startsWith('Type${NsgFieldUsage.recentRequestsLimit + 4} '));
  });
}
