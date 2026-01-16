import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:nsg_data/nsg_data.dart';

///Интерфейс объекта реализующего связь между NsgDataItem и строками Excel таблицы
///При инициализации заполнится значениями из строки `row` листа `sheet`
abstract class NsgExcelImport<T extends NsgDataItem> {
  NsgExcelImport(this.sheet, this.row) {
    fillValues();
  }

  bool enableLog = false;

  ///Соответствие полей объекта со столбцами таблицы.
  ///Map<ПолеОбъекта, СтолбецТаблицы> Столбец таблицы задается в формате строки `"C"` или номером столбца `1`
  Map<String, dynamic> get excelMap;

  ///Создание кастомных парсеров для сложных полей (например NsgEnum)
  ///Map<ПолеОбъекта, КастомнаяОбработка> КастомнаяОбработка - Функция, где `fieldType` - тип поля Объекта, value - значение ячейки таблицы
  Map<String, dynamic Function(Type fieldType, dynamic value)> customParser = {};

  final Sheet sheet;
  final int row;
  T getNewObject();

  late T object = getNewObject();

  int _getExcelColumn(dynamic column) {
    if (column is String) {
      var num = column.tryParseInt(emptyValue: -1, enableLog: enableLog);
      if (num == -1) {
        return _columnLetterToNumber(column);
      } else {
        return num;
      }
    } else if (column is int) {
      return column;
    } else {
      throw Exception("Неверно указан столбец: column = ${column.toString()}");
    }
  }

  int _columnLetterToNumber(String column) {
    int result = 0;
    column = column.toUpperCase();
    for (int i = 0; i < column.length; i++) {
      int charCode = column.codeUnitAt(i) - 'A'.codeUnitAt(0);
      result = result * 26 + charCode;
    }
    return result;
  }

  Data? _getExcelValue(dynamic column) {
    try {
      return sheet.row(row)[_getExcelColumn(column)];
    } catch (ex) {
      return null;
    }
  }

  ///Заполнить объект значениями из строки `row`, согласно `excelMap`.
  ///Реализуют стандартную логику для записи значений в поля объекта "как есть".
  ///Для сложной логики необходимо использовать `Map customParser`, для настройки парсинга уникальных полей по особой логике
  T fillValues() {
    object = getNewObject();
    object.newRecord();
    excelMap.forEach((fieldName, excelColumn) {
      assert(object.fieldList.fields.containsKey(fieldName), '!!! Не существует поля с именем: $fieldName в объекте: ${object.runtimeType}');

      Data? val = _getExcelValue(excelColumn);
      var fieldType = object.getFieldValue(fieldName).runtimeType;

      if (customParser.containsKey(fieldName)) {
        var value = customParser[fieldName]!(fieldType, val?.value);
        object.setFieldValue(fieldName, value);
      } else {
        if (fieldType == DateTime) {
          DateTime newValue;

          bool excelDataFormat = false;
          var date = safeCell(val).split("T");
          if (date.length < 2) {
            date = safeCell(val).split(".");
          } else {
            excelDataFormat = true;
            date = date[0].split("-");
          }
          if (date.length >= 3) {
            if (excelDataFormat) {
              newValue = DateTime(date[0].tryParseInt(emptyValue: 0), date[1].tryParseInt(emptyValue: 1), date[2].tryParseInt(emptyValue: 1));
            } else {
              newValue = DateTime(date[2].tryParseInt(emptyValue: 0), date[1].tryParseInt(emptyValue: 1), date[0].tryParseInt(emptyValue: 1));
            }
          } else if (date.length == 2) {
            newValue = DateTime(date[1].tryParseInt(emptyValue: 1), date[0].tryParseInt(emptyValue: 1));
          } else {
            newValue = DateTime(safeCell(val).tryParseInt(emptyValue: 0));
          }
          if (newValue.isBefore(DateTime(10))) {
            object.setFieldValue(fieldName, object.fieldList.fields[fieldName]!.defaultValue);
          } else {
            object.setFieldValue(fieldName, newValue);
          }
        } else if (fieldType == int) {
          object.setFieldValue(fieldName, safeCell(val).tryParseInt(emptyValue: object.fieldList.fields[fieldName]!.defaultValue));
        } else if (fieldType == double) {
          object.setFieldValue(fieldName, safeCell(val).tryParseDouble(emptyValue: object.fieldList.fields[fieldName]!.defaultValue));
        } else if (fieldType == bool) {
          object.setFieldValue(fieldName, safeCell(val).tryParseBool(emptyValue: object.fieldList.fields[fieldName]!.defaultValue));
        } else {
          object.setFieldValue(fieldName, safeCell(val));
        }
      }
    });

    var valid = object.validateFieldValues();

    if (!valid.isValid) {
      log(valid.errorMessage);
      object = getNewObject();
    }

    return object;
  }

  static String safeCell(dynamic data) {
    if (data == null) {
      return "";
    }
    if (data is Data) {
      return data.value?.toString() ?? "";
    } else if (data is CellValue) {
      if (data is TextCellValue) {
        return data.value.toString();
      } else if (data is FormulaCellValue) {
        return data.formula;
      } else if (data is IntCellValue) {
        return data.value.toString();
      } else if (data is BoolCellValue) {
        return data.value.toString();
      } else if (data is DoubleCellValue) {
        return data.value.toString();
      } else if (data is DateCellValue) {
        return "${data.year}-${data.month}-${data.day}";
      } else if (data is TimeCellValue) {
        return "${data.hour}:${data.minute}:${data.second}";
      } else if (data is DateTimeCellValue) {
        return DateTime(data.year, data.month, data.day, data.hour, data.minute, data.second).toString();
      }
    }
    return "";
  }
}

class NsgExcel {
  ///Открывает диалог для выбора excel файла. После выбора возвращает объект Excel
  static Future<Excel> getExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (result != null) {
      var fileBytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(fileBytes);
      return excel;
    } else {
      throw Exception("Не удалось прочитать файл");
    }
  }
}

extension ParseExcel on Excel {
  ///Реализует парсинг всех листов книги (если не заданы конкретные листы `sheetNumbers`) вызывает `parsing` для КАЖДОЙ строки.
  void parseExcel(void Function(Sheet sheet, int row) parsing, {int firstDataRow = 1, List<int>? sheetNumbers, int? lastDataRow}) {
    assert(firstDataRow > 0, "Значение первой строки должно быть положительным числом больше 0, сейчас: $firstDataRow");
    assert(
      lastDataRow == null || lastDataRow >= firstDataRow,
      "Значение последней строки должно быть положительным числом большим или равным firstDataRow ($firstDataRow), сейчас: $lastDataRow",
    );
    if (sheetNumbers != null) {
      assert(sheetNumbers.any((i) => i > 0), "Значение всех элементов sheetNumbers долно быть положительным числом больше 0, сейчас: $sheetNumbers");
      for (var sheetNumber in sheetNumbers) {
        if (sheets.keys.toList().length >= sheetNumber) {
          var ex = this[sheets.keys.toList()[sheetNumber - 1]];
          ex.parseSheet(parsing, firstDataRow: firstDataRow, lastDataRow: lastDataRow);
        }
      }
    } else {
      for (var sheet in sheets.keys) {
        var ex = this[sheet];
        ex.parseSheet(parsing, firstDataRow: firstDataRow, lastDataRow: lastDataRow);
      }
    }
  }
}

extension ParseSheet on Sheet {
  ///Реализует парсинг листа кники вызывает `parsing` для КАЖДОЙ строки
  void parseSheet(void Function(Sheet sheet, int row) parsing, {int firstDataRow = 1, int? lastDataRow}) {
    assert(firstDataRow > 0, "Значение первой строки должно быть положительным числом больше 0, сейчас: $firstDataRow");
    assert(
      lastDataRow == null || lastDataRow >= firstDataRow,
      "Значение последней строки должно быть положительным числом большим или равным firstDataRow ($firstDataRow), сейчас: $lastDataRow",
    );
    firstDataRow--;
    for (int row = firstDataRow; row < (lastDataRow ?? maxRows); row++) {
      parsing(this, row);
    }
  }
}

extension ParseString on String {
  int tryParseInt({int emptyValue = -999999, bool enableLog = kDebugMode}) {
    try {
      return tryParseNum(emptyValue: emptyValue, enableLog: enableLog) as int;
    } catch (ex) {
      if (enableLog) log(ex.toString());
      return emptyValue;
    }
  }

  double tryParseDouble({double emptyValue = -999999, bool enableLog = kDebugMode}) {
    try {
      return tryParseNum(emptyValue: emptyValue, enableLog: enableLog) as double;
    } catch (ex) {
      if (enableLog) log(ex.toString());
      return emptyValue;
    }
  }

  num tryParseNum({num emptyValue = -999999, bool enableLog = kDebugMode}) {
    try {
      num ans = num.parse(this);
      return ans;
    } catch (ex) {
      if (enableLog) log(ex.toString());
      return emptyValue;
    }
  }

  bool tryParseBool({bool emptyValue = false, bool enableLog = kDebugMode}) {
    try {
      bool ans = bool.parse(this);
      return ans;
    } catch (ex) {
      if (enableLog) log(ex.toString());
      return emptyValue;
    }
  }

  String get normalizeString {
    // Убираем пробелы в начале и конце, заменяем множественные пробелы на один
    String normalized = trim().replaceAll(RegExp(r'\s+'), ' ');
    // Приводим к нижнему регистру
    normalized = normalized.toLowerCase();
    // Нормализация Unicode (NFC)
    normalized = const Utf8Decoder().convert(const Utf8Encoder().convert(normalized));
    return normalized;
  }
}
