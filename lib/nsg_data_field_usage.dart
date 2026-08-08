import 'package:flutter/foundation.dart';

/// Диагностика фактического использования полей объектов (#1394, пилот к #1383).
///
/// Две независимые вещи:
///
/// 1. **Сбор обращений** ([collect]) — какие поля объектов реально читаются на
///    экране. Включается приложением ЯВНО и работает только в debug: в release
///    вызов вырезается по `kDebugMode` (это компайл-тайм константа), так что
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
    if (!kDebugMode || !collect) return;
    if (scenario == value) return;
    scenario = value;
    if (logFirstAccess) debugPrint('NSGFIELD --- scenario: $value');
  }

  /// Зафиксировать обращение к полю. Вызывать только под `kDebugMode`.
  static void record(String typeName, String fieldName) {
    final current = _currentScenario;
    final byType = _usage.putIfAbsent(current, () => <String, Set<String>>{});
    final fields = byType.putIfAbsent(typeName, () => <String>{});
    if (fields.add(fieldName) && logFirstAccess) {
      debugPrint('NSGFIELD $current $typeName.$fieldName');
    }
  }

  /// Сообщить о чтении поля, которое не запрашивалось из БД.
  static void reportEmptyFieldAccess(String typeName, String fieldName) {
    if (kDebugMode && collect) {
      final byType = _usage.putIfAbsent('!empty:$_currentScenario', () => <String, Set<String>>{});
      byType.putIfAbsent(typeName, () => <String>{}).add(fieldName);
    }
    final hook = onEmptyFieldAccess;
    if (hook == null) return;
    if (!_reportedEmpty.add('$typeName.$fieldName')) return;
    hook(typeName, fieldName);
  }

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
  }
}
