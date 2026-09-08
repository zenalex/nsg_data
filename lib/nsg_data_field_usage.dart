import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'nsg_data_item.dart';

/// Диагностика фактического использования полей объектов (#1394, пилот к #1383).
///
/// Две независимые вещи:
///
/// 1. **Сбор обращений** ([collect]) — какие поля объектов реально читаются на
///    экране. Включается приложением ЯВНО и работает только в debug: в release
///    вызов вырезается по `kReleaseMode` (это компайл-тайм константа), так что
///    накладных расходов в проде нет. Нужен, чтобы список `neededFields`
///    получался замером, а не чтением вёрстки: обращения из сортировок, поиска,
///    шаринга и аналитики глазами не находятся.
///
/// 2. **Хук нарушений** ([onEmptyFieldAccess]) — обращение к полю, которое
///    умышленно не запрашивалось из БД. Работает в ЛЮБОМ режиме сборки, потому
///    что в release `assert` вырезан и пропущенное поле молча отдаёт
///    `defaultValue`. Хук позволяет приложению отправить такое обращение в
///    GlitchTip и увидеть пропущенный путь событием, а не жалобой
///    «поле пустое». Дедупликация внутри — по одному событию на пару
///    `тип.поле` за сессию, чтобы обращение из `ListView.builder` не
///    превратилось в шторм.
class NsgFieldUsage {
  NsgFieldUsage._();

  /// Собирать статистику обращений к полям. Только debug.
  static bool collect = false;

  /// Ронять debug на чтении незапрошенного поля.
  ///
  /// По умолчанию ВЫКЛЮЧЕНО, и это осознанно. Для поиска промахов assert — плохой
  /// инструмент: он обрывает построение поддерева на ПЕРВОМ нарушении, остальные
  /// в этом прогоне уже не проявятся. Прогон за прогоном находится по одному полю,
  /// а между ними — пересборка. Лог показывает весь список сразу, за один заход.
  ///
  /// Включать имеет смысл, когда набор полей уже устоялся: тогда падение —
  /// это регрессия, и её надо ловить громко.
  static bool strictEmptyFields = false;

  /// Считать ли ошибкой чтение табличной части, которую не загружали.
  ///
  /// Выключено по умолчанию сознательно. Для обычных полей признак «не читалось»
  /// появляется только при сужении запроса, то есть редко. У табличных частей
  /// «не загружена» — это нормальное состояние почти везде: их не тянут, пока
  /// экрану не понадобятся. Включить проверку без разбора значит уронить debug
  /// на первом же экране, который читает таблицу просто на всякий случай.
  /// Поэтому: включаем флагом, смотрим список реальных мест, чиним, и только
  /// потом обсуждаем умолчание.
  static bool reportUnloadedTables = false;

  /// Дополнительно ронять debug на таком чтении. Отдельно от [reportUnloadedTables],
  /// потому что сначала надо СНЯТЬ список мест (assert обрывает прогон на первом),
  /// а уже потом включать строгость.
  static bool strictUnloadedTables = false;

  /// Печатать в консоль первое обращение к паре `тип.поле` в рамках сценария.
  /// Даёт упорядоченную ленту, по которой видно, что понадобилось списку, а что
  /// уже карточке.
  static bool logFirstAccess = true;

  /// Метка текущего сценария. Всё, что прочитано после её смены, попадает в
  /// свой разрез. Приложение переставляет её на навигации.
  static String scenario = 'boot';

  /// Если приложение задало резолвер — метка берётся из него на каждом
  /// обращении. Так разрез получается по факту (например, по текущему роуту), а
  /// не по расставленным вручную меткам, которые легко забыть переключить на
  /// возврате назад.
  static String Function()? scenarioResolver;

  static String get _currentScenario {
    final resolver = scenarioResolver;
    if (resolver == null) return scenario;
    try {
      final value = resolver();
      return value.isEmpty ? scenario : value;
    } catch (_) {
      return scenario;
    }
  }

  /// сценарий -> тип объекта -> прочитанные поля
  static final Map<String, Map<String, Set<String>>> _usage = {};

  /// Хук обращения к незапрошенному полю. Вызывается и в release.
  static void Function(String typeName, String fieldName)? onEmptyFieldAccess;

  /// То же самое, но с ОБЪЕКТОМ, у которого промахнулась ссылка. Если задан —
  /// вызывается вместо [onEmptyFieldAccess], а не вместе с ним.
  ///
  /// `owner` заполнен только для промаха референта
  /// ([reportMissingReferent]); у обычного промаха поля его нет.
  ///
  /// Зачем понадобился (NSG-SOFT/futbolista-tasks#1954). Приложение
  /// перепроверяет промах через паузу, чтобы отличить «пусто навсегда» от
  /// «пусто 200 мс»: гонку с ленивой дочиткой чинить нельзя, а пробел в наборе
  /// запроса — нужно. Зная только «тип.поле», перепроверить можно лишь обходом
  /// ВСЕГО ведра кэша: «не осталось ли неразрешённых ссылок этого поля вообще».
  /// Для популярного типа это условие не выполняется никогда — рядом всегда
  /// лежат десятки объектов, приехавших референтом чужого запроса и не
  /// собирающихся резолвиться. Замер по проду: у `MatchItem.teamAwayId` в кэше
  /// 50 ссылок, из них 35 неразрешённых — и настоящая гонка в этом шуме
  /// неотличима от настоящего пробела.
  ///
  /// С объектом перепроверка становится точечной: спросить ТУ ЖЕ ссылку у ТОГО
  /// ЖЕ объекта. Заодно она дешевле — один `getReferent` вместо обхода ведра.
  ///
  /// Обходной путь без объекта невозможен в принципе: снаружи промахи
  /// неразличимы, а пометки происхождения на объектах в кэше нет.
  static void Function(String typeName, String fieldName, NsgDataItem? owner)? onEmptyFieldAccessWithOwner;

  /// Пары `тип.поле`, о которых уже сообщили — чтобы не слать дубли.
  static final Set<String> _reportedEmpty = <String>{};

  /// Сменить метку сценария (и залогировать переход).
  static void setScenario(String value) {
    if (kReleaseMode || !collect) return;
    if (scenario == value) return;
    scenario = value;
    if (logFirstAccess) debugPrint('NSGFIELD --- scenario: $value');
  }

  /// Глубина подавления сбора. Механические обходы всех полей (копирование
  /// объекта, сериализация) читают поле за полем, но это не «экрану нужно
  /// поле» — это перекладывание значений. Если их считать, набор любого экрана
  /// сходится ко «всем полям»: достаточно один раз влить в объект списка
  /// полностью прочитанную карточку.
  static int _internalDepth = 0;

  /// Начать участок, где обращения к полям не считаются нуждами экрана.
  static void beginInternalAccess() => _internalDepth++;

  /// Закончить такой участок. Вызывать в `finally`.
  static void endInternalAccess() {
    if (_internalDepth > 0) _internalDepth--;
  }

  /// Зафиксировать обращение к полю. Вызывать только под `!kReleaseMode`.
  static void record(String typeName, String fieldName) {
    if (_internalDepth > 0) return;
    final current = _currentScenario;
    final byType = _usage.putIfAbsent(current, () => <String, Set<String>>{});
    final fields = byType.putIfAbsent(typeName, () => <String>{});
    if (fields.add(fieldName) && logFirstAccess) {
      debugPrint('NSGFIELD $current $typeName.$fieldName');
    }
  }

  /// Сообщить о чтении поля, которое не запрашивалось из БД.
  ///
  /// `owner` — объект, у которого промахнулась ссылка; доезжает до
  /// [onEmptyFieldAccessWithOwner] и нужен приложению для точечной
  /// перепроверки. Дедупликация и порядок проверок от него не зависят: старый
  /// хук получает ровно то же, что и раньше.
  static void reportEmptyFieldAccess(String typeName, String fieldName, {NsgDataItem? owner}) {
    if (!kReleaseMode && collect) {
      final byType = _usage.putIfAbsent('!empty:$_currentScenario', () => <String, Set<String>>{});
      byType.putIfAbsent(typeName, () => <String>{}).add(fieldName);
    }
    final hookWithOwner = onEmptyFieldAccessWithOwner;
    final hook = onEmptyFieldAccess;
    if (hookWithOwner == null && hook == null) return;
    // Пометку «об этой паре уже сообщили» ставим ПОСЛЕ проверки хуков и до
    // вызова — как и было. Иначе снятый на время хук (так приложение гасит
    // собственную пробу кэша, #1547) съедал бы первое настоящее событие.
    if (!_reportedEmpty.add('$typeName.$fieldName')) return;
    if (hookWithOwner != null) {
      hookWithOwner(typeName, fieldName, owner);
      return;
    }
    hook!(typeName, fieldName);
  }

  /// Ссылка задана, а объекта по ней в кэше нет — его не дочитали.
  ///
  /// Экран получает пустышку и молча рисует пустоту: имя команды исчезает, а
  /// ошибки нигде нет. Это тот же класс промаха, что и чтение незапрошенного
  /// поля, только заметить его ещё труднее.
  ///
  /// Проверка стоит в ветке ПРОМАХА [NsgDataReferenceField.getReferent], а не на
  /// каждом чтении поля. Пока ссылки резолвятся, этой ветки не существует —
  /// значит в нормальной работе диагностика не стоит ничего, и её можно держать
  /// включённой в релизе. Замер к #1383 показал, что сужение полей выигрыша в
  /// скорости не даёт, объём снимает сжатие ответов, — поэтому платить за
  /// диагностику на каждом чтении смысла нет, а за эту не платим вовсе.
  ///
  /// Метка поля отличается от обычного промаха, чтобы в GlitchTip это была
  /// отдельная группа, а не подмешивалось к чтениям полей.
  /// `owner` — объект, у которого ссылка не разрешилась. Нужен приложению,
  /// чтобы перепроверить ИМЕННО ЭТУ ссылку, а не всё ведро кэша: см.
  /// [onEmptyFieldAccessWithOwner].
  static void reportMissingReferent(String typeName, String fieldName, {NsgDataItem? owner}) =>
      reportEmptyFieldAccess(typeName, '$fieldName:referent', owner: owner);

  /// Печатать в консоль, когда асинхронное дочитывание ссылки запрошено ВО ВРЕМЯ
  /// СБОРКИ КАДРА. Только лог и только не-release; хук
  /// [onAsyncReferentDuringBuild] работает в ЛЮБОМ режиме сборки.
  ///
  /// Зачем: до NSG-SOFT/futbolista-tasks#1921 `getReferentAsync` не ходил в сеть
  /// вообще (ветка загрузки была мертва), поэтому вызвать его из `build()` было
  /// безобидно. Теперь это сетевой запрос, и у такого вызова два исхода, оба
  /// плохих: результат в сборке всё равно не дождаться, а `Future` без `await`
  /// при обрыве связи всплывает в `PlatformDispatcher.onError` необработанным.
  ///
  /// Генерируемые обёртки `xxxAsync()` есть у каждой ссылки каждой модели и
  /// выглядят как безопасная замена синхронному геттеру — поэтому предупреждение
  /// включено по умолчанию.
  static bool warnAsyncReferentDuringBuild = true;

  /// Дополнительно ронять debug на таком вызове. Отдельным флагом и по той же
  /// причине, что у [strictEmptyFields]: сначала снимают список мест логом, и
  /// только потом включают строгость.
  ///
  /// ⚠️ Падает НЕ так, как [strictEmptyFields]. Тот сидит в синхронном геттере и
  /// валит сборку на месте. Здесь метод `async`, и синхронный throw из его тела
  /// Dart заворачивает в возвращаемый `Future` — то есть нарушение прилетит
  /// обработчику ошибки, а `typeAsync().ignore()` проглотит его молча. Громким
  /// сигналом остаётся лог; assert полезен там, где вызов всё-таки `await`-ится.
  static bool strictAsyncReferentDuringBuild = false;

  /// Хук для приложения: то же событие можно увести в телеметрию.
  ///
  /// Работает в ЛЮБОМ режиме сборки, и это принципиально — ровно как у
  /// [onEmptyFieldAccess]. Лог виден только разработчику на своей машине, а
  /// нарушение живёт в проде: в release `assert` вырезан, `debugPrint` никто не
  /// читает, и единственный способ узнать о вызове — событие отсюда.
  ///
  /// Здесь на этом уже спотыкались: сначала весь метод выходил по `kReleaseMode`,
  /// а Sentry в приложении поднимается наоборот, ТОЛЬКО в release. Окна не
  /// пересекались, и подключённый хук не дал бы ни одного события.
  static void Function(String typeName, String fieldName, String phase)? onAsyncReferentDuringBuild;

  /// Пары `тип.поле`, о которых уже предупредили.
  static final Set<String> _reportedAsyncDuringBuild = <String>{};

  /// Фаза кадра, если сейчас идёт работа над кадром, иначе `null`.
  ///
  /// `postFrameCallbacks` СОЗНАТЕЛЬНО не считается нарушением: это законное
  /// место, чтобы запустить дочитывание после отрисовки. `idle` — тем более.
  static String? currentFramePhase() {
    try {
      switch (SchedulerBinding.instance.schedulerPhase) {
        case SchedulerPhase.transientCallbacks:
          return 'transientCallbacks';
        case SchedulerPhase.midFrameMicrotasks:
          return 'midFrameMicrotasks';
        case SchedulerPhase.persistentCallbacks:
          return 'persistentCallbacks';
        case SchedulerPhase.idle:
        case SchedulerPhase.postFrameCallbacks:
          return null;
      }
    } catch (_) {
      // Биндинг не поднят (чистый unit-тест, изолят без Flutter) — фазы нет.
      return null;
    }
  }

  /// Асинхронное дочитывание ссылки запрошено во время сборки кадра.
  ///
  /// Зовётся из `getReferentAsync` НА ВХОДЕ, а не перед самим запросом, и это
  /// намеренно: при тёплом кэше запрос не уходит и вызов «работает», но место
  /// вызова от этого не перестаёт быть неверным — на холодном кэше тот же код
  /// пойдёт в сеть. Предупреждать надо о call-site, а не о везении.
  static void reportAsyncReferentDuringBuild(String typeName, String fieldName) {
    final hook = onAsyncReferentDuringBuild;
    // Лог и строгость — не-release, хук — всегда. Если не нужно ничего, выходим
    // до опроса фазы: это единственная работа, которую метод делает в проде у
    // приложения, не подключившего хук.
    final wantsLog = !kReleaseMode && warnAsyncReferentDuringBuild;
    if (hook == null && !wantsLog && !(!kReleaseMode && strictAsyncReferentDuringBuild)) return;
    final phase = currentFramePhase();
    if (phase == null) return;
    // Один раз на пару «тип.поле»: перестраивающийся виджет иначе даст шторм
    // по 60 сообщений в секунду. Дедуп общий с остальной диагностикой — его
    // чистит reset().
    if (!_reportedAsyncDuringBuild.add('$typeName.$fieldName')) return;
    if (wantsLog) {
      debugPrint('[FIELDS] !!! $typeName.$fieldName: getReferentAsync во время сборки кадра ($phase). '
          'Результат здесь не дождаться, а Future без await всплывёт необработанным. '
          'Для «возьму, если загружено» есть синхронный getReferent; для списка — referenceList запроса.');
    }
    hook?.call(typeName, fieldName, phase);
    assert(!strictAsyncReferentDuringBuild,
        '!!! getReferentAsync во время сборки кадра ($phase). Объект: $typeName, поле: $fieldName');
  }

  /// Сколько последних запросов помнить. Глубина «что грузилось перед этим
  /// экраном»: одного мало (объект часто грузят раньше, чем читают поле),
  /// а длинный хвост уводит в предыдущие экраны.
  static const int recentRequestsLimit = 12;

  /// Сколько символов списка ссылок держать в записи.
  ///
  /// Было 120 — и это ровно тот размер, на котором диагностика начинает врать.
  /// Обрезанный список отвечает на вопрос «есть ли поле F в наборе» только
  /// «да»; «нет» из него НЕ следует, но читается именно так. Цена уже
  /// заплачена: две задачи закрыты выводом «в запросе нет собственного
  /// `photoId` команды», а `photoId` и `cityId` стояли сразу за срезом.
  ///
  /// 800 — не на глаз. Замер по 511 записям трейла из 43 живых событий:
  /// резалось 30% записей, истинная длина срезанных — медиана 266, p90 654,
  /// максимум 654 символа (`addAllReferences(MatchItem)`, 40 полей). Порог 400
  /// оставил бы срезанными 17%, 512 — 11%, 800 — ни одной, и это с запасом на
  /// рост модели.
  ///
  /// Бюджет события считан: контекст `recentRequests` растёт с ~1.2 КБ до ~2 КБ
  /// (максимум на реальных данных — 3.2 КБ). Абсолютный потолок буфера —
  /// 12 × (обвязка ~64 + 800 + 1) ≈ 10 КБ, на порядки ниже лимита события,
  /// поэтому глубину буфера ради длины строки резать не потребовалось.
  static const int requestRefsLimit = 800;

  static final List<String> _recentRequests = <String>[];

  /// Запомнить выполненный запрос вместе с набором дочитываемых ссылок.
  ///
  /// Зачем: промах вида `PlayerStats.teamPlayerId:referent` сам по себе
  /// НЕАДРЕСУЕМ. Известно, чего не дочитали, но не известно, какой запрос грузил
  /// объект, — а значит и какому контроллеру править `referenceList`. Роут
  /// сужает круг, но у популярных типов на одном экране работает несколько
  /// контроллеров сразу; ровно на этом встали #1429, #1430 и #1479.
  ///
  /// Снимок делается в точке, где `referenceList` уже окончательный, то есть
  /// пишется именно тот набор, из-за отсутствия поля в котором промах и
  /// случился. Починка после этого — сверка двух списков, а не чтение вёрстки.
  ///
  /// Работает в ЛЮБОМ режиме сборки: события приходят из релиза, там буфер и
  /// нужен. Цена — одна строка на сетевой запрос, на фоне самого запроса
  /// неизмерима. В консоль ничего не пишется: крошки Sentry — дефицитный ресурс
  /// (окно ~100 записей), поэтому буфер прикладывается к событию целиком и
  /// только в момент отправки.
  static void noteRequest(String typeName, String function, List<String>? referenceList) {
    final refs = _shortenReferences(referenceList);
    // Только путь: хост во всех записях один и тот же, а место в событии не резиновое.
    final path = Uri.tryParse(function)?.path ?? function;
    final entry = '$typeName ${path.isEmpty ? function : path} [ref: $refs]';
    // Одинаковую запись держим в одном экземпляре — в последнем по времени.
    // Слотов всего 12, и каждый занятый повтором — это невидимый запрос другого
    // контроллера. Повторы бывают двух родов, и оба обесценивают буфер:
    // подряд идущие (точка съёма стоит внутри тела, которое переигрывает
    // RetryOptions.retry вплоть до autoRepeateCount, по умолчанию 10 — один
    // обрыв связи забивал буфер целиком) и вразбивку (один и тот же список
    // перечитывается по кругу на живом экране). На замере по живым событиям
    // точными дублями занято 11% слотов.
    _recentRequests.remove(entry);
    _recentRequests.add(entry);
    if (_recentRequests.length > recentRequestsLimit) {
      _recentRequests.removeRange(0, _recentRequests.length - recentRequestsLimit);
    }
  }

  /// Список ссылок для записи трейла: целиком, пока влезает в [requestRefsLimit].
  ///
  /// Если не влезает — режем ПО ГРАНИЦЕ ПОЛЯ и дописываем, сколько полей не
  /// поместилось: `a,b,c,…+17`. Обрубок посреди имени (`tournament…`) читается
  /// как поле, а не как срез, и именно так рождается вывод «поля в запросе
  /// нет». Счётчик снимает вопрос: набор неполный, и сколько именно осталось за
  /// кадром — видно.
  static String _shortenReferences(List<String>? referenceList) {
    if (referenceList == null || referenceList.isEmpty) return '—';
    final buffer = StringBuffer();
    var kept = 0;
    for (final reference in referenceList) {
      // Первое поле берём всегда: запись без единого имени бесполезна.
      if (kept > 0 && buffer.length + 1 + reference.length > requestRefsLimit) break;
      if (kept > 0) buffer.write(',');
      buffer.write(reference);
      kept++;
    }
    final dropped = referenceList.length - kept;
    return dropped == 0 ? buffer.toString() : '$buffer,…+$dropped';
  }

  /// Последние запросы — от старого к новому. Приложение прикладывает их к
  /// отчёту о промахе.
  static List<String> get recentRequests => List<String>.unmodifiable(_recentRequests);

  /// Снятая статистика: сценарий -> тип -> отсортированный список полей.
  static Map<String, Map<String, List<String>>> report() {
    final result = <String, Map<String, List<String>>>{};
    _usage.forEach((scenarioName, byType) {
      final types = <String, List<String>>{};
      byType.forEach((typeName, fields) {
        types[typeName] = fields.toList()..sort();
      });
      result[scenarioName] = types;
    });
    return result;
  }

  /// Плоский текстовый отчёт — удобно выцепить из консоли одним куском.
  static String reportAsText() {
    final buffer = StringBuffer();
    final data = report();
    for (final scenarioName in data.keys.toList()..sort()) {
      buffer.writeln('== $scenarioName ==');
      final byType = data[scenarioName]!;
      for (final typeName in byType.keys.toList()..sort()) {
        buffer.writeln('$typeName: ${byType[typeName]!.join(',')}');
      }
    }
    return buffer.toString();
  }

  static void reset() {
    _usage.clear();
    _reportedEmpty.clear();
    _reportedAsyncDuringBuild.clear();
    _recentRequests.clear();
  }
}
