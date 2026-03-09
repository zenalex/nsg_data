import 'package:excel/excel.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/nsg_excel_import.dart';
import 'package:string_similarity/string_similarity.dart';

/// Описание колонки для поиска заголовка: варианты названий и привязка к полю модели.
class ColumnDefinition<T extends NsgDataItem> {
  ColumnDefinition({required this.aliases, this.fieldName, this.required = true}) : id = T.toString() + Guid.newGuid();

  /// Уникальный идентификатор колонки (например 'fio', 'place').
  final String id;

  /// Допустимые варианты названия столбца в Excel (например ['ФИО', 'Фамилия Имя Отчество']).
  final List<String> aliases;

  /// Имя поля (например PlayerItemGenerated.nameLastName).
  /// Если null, колонка используется только для поиска строки заголовка и не попадает в excelMap.
  final String? fieldName;

  /// Обязательная ли колонка для признания строки заголовком.
  final bool required;

  Type get type => T;
}

/// Результат поиска строки заголовков: индекс строки и позиции колонок по id.
class DetectedHeader {
  const DetectedHeader({required this.rowIndex, required this.columns});

  /// Индекс строки заголовка (0-based).
  final int rowIndex;

  /// Соответствие id колонки -> индекс столбца (0-based).
  final Map<String, int> columns;

  int get firstDataRow => rowIndex + 2;
}

class NsgExcelAliases {
  static String _normalize(String? value) {
    if (value == null) return '';
    final lower = value.toLowerCase().trim();
    return lower.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.,;:()\-_/\\]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static double _bestAliasScore(String cellValue, List<String> aliases) {
    final normCell = _normalize(cellValue);
    if (normCell.isEmpty) return 0.0;

    double best = 0.0;
    for (final alias in aliases) {
      final score = StringSimilarity.compareTwoStrings(normCell, _normalize(alias));
      if (score > best) best = score;
    }
    return best;
  }

  /// Сканирует первые строки листа и находит строку, наиболее похожую на заголовок
  /// по заданным вариантам названий колонок. Возвращает индекс строки и позиции столбцов.
  static DetectedHeader? findHeaderRow(
    Sheet sheet,
    List<ColumnDefinition> config, {
    int maxRowsToScan = 50,
    double minScorePerCell = 0.6,
    int minRequiredMatches = 2,
  }) {
    int bestRowIndex = -1;
    double bestScore = 0.0;
    Map<String, int> bestColumns = {};

    final lastRow = sheet.maxRows < maxRowsToScan ? sheet.maxRows : maxRowsToScan;

    for (var rowIndex = 0; rowIndex < lastRow; rowIndex++) {
      final row = sheet.row(rowIndex);
      final Map<String, (int colIndex, double score)> rowMatches = {};
      var colIndex = 0;
      for (final cell in row) {
        final value = NsgExcelImport.safeCell(cell);
        final str = value.toString().trim();
        if (str.isNotEmpty) {
          for (final colDef in config) {
            final score = _bestAliasScore(str, colDef.aliases);
            if (score >= minScorePerCell) {
              final existing = rowMatches[colDef.id];
              if (existing == null || score > existing.$2) {
                rowMatches[colDef.id] = (colIndex, score);
              }
            }
          }
        }
        colIndex++;
      }

      if (rowMatches.isEmpty) continue;

      final requiredIds = config.where((c) => c.required).map((c) => c.id).toSet();
      final requiredMatched = rowMatches.keys.where((id) => requiredIds.contains(id)).length;

      if (requiredMatched < minRequiredMatches) continue;

      final avgScore = rowMatches.values.map((e) => e.$2).fold<double>(0.0, (a, b) => a + b) / rowMatches.length;

      final compositeScore = requiredMatched + avgScore;

      if (compositeScore > bestScore) {
        bestScore = compositeScore;
        bestRowIndex = rowIndex;
        bestColumns = {for (final entry in rowMatches.entries) entry.key: entry.value.$1};
      }
    }

    if (bestRowIndex == -1) return null;

    return DetectedHeader(rowIndex: bestRowIndex, columns: bestColumns);
  }

  /// Собирает карту «поле модели -> буква столбца Excel» по найденному заголовку и конфигу.
  /// [allowedFieldNames] — если задано, в карту попадают только эти поля (для одной модели).
  static List<ImportModel> buildExcelMapFromHeader(
    DetectedHeader header,
    List<ColumnDefinition> config,
    String Function(int oneBasedColumnIndex) intToExcelColumn, {
    Set<String>? allowedFieldNames,
  }) {
    final List<ImportModel> list = [];

    for (final colDef in config) {
      final fieldName = colDef.fieldName;
      if (fieldName == null) continue;
      if (allowedFieldNames != null && !allowedFieldNames.contains(fieldName)) {
        continue;
      }
      final colIndex = header.columns[colDef.id];
      if (colIndex != null) {
        final importModel = ImportModel(colDef.type);
        importModel.fieldsMap[fieldName] = intToExcelColumn(colIndex + 1);
        list.add(importModel);
      }
    }
    return list;
  }
}

class ImportModel {
  ImportModel(this.type);

  Type type;
  final Map<String, dynamic> fieldsMap = {};
}

extension GetFields on List<ImportModel> {
  Map<String, dynamic> getFieldsMap<T extends NsgDataItem>() {
    var maps = where((i) => i.type == T).toList();
    var result = <String, dynamic>{};
    for (var map in maps) {
      result.addAll(map.fieldsMap);
    }
    return result;
  }
}
