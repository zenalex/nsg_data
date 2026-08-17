import 'package:flutter/foundation.dart';

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
  static void reportEmptyFieldAccess(String typeName, String fieldName) {
    if (!kReleaseMode && collect) {
      final byType = _usage.putIfAbsent('!empty:$_currentScenario', () => <String, Set<String>>{});
      byType.putIfAbsent(typeName, () => <String>{}).add(fieldName);
    }
    final hook = onEmptyFieldAccess;
    if (hook == null) return;
    if (!_reportedEmpty.add('$typeName.$fieldName')) return;
    hook(typeName, fieldName);
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
  static void reportMissingReferent(String typeName, String fieldName) => reportEmptyFieldAccess(typeName, '$fieldName:referent');

  /// Сколько последних запросов помнить. Глубина «что грузилось перед этим
  /// экраном»: одного мало (объект часто грузят раньше, чем читают поле),
  /// а длинный хвост уводит в предыдущие экраны.
  static const int recentRequestsLimit = 12;

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
    var refs = (referenceList == null || referenceList.isEmpty) ? '—' : referenceList.join(',');
    if (refs.length > 120) refs = '${refs.substring(0, 120)}…';
    // Только путь: хост во всех записях один и тот же, а место в событии не резиновое.
    final path = Uri.tryParse(function)?.path ?? function;
    _recentRequests.add('$typeName ${path.isEmpty ? function : path} [ref: $refs]');
    if (_recentRequests.length > recentRequestsLimit) {
      _recentRequests.removeRange(0, _recentRequests.length - recentRequestsLimit);
    }
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
    _recentRequests.clear();
  }
}
