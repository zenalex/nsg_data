import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NsgDataOptions {
  /// Форматирование даты по умолчанию
  String dateformat = 'dd.MM.yy';

  /// Путь к файлу конфигурации
  String get configPath => _configFile.path;
  set configPath(String value) {
    _configFile = File(value);
    config = _getConfig(_configFile);
  }

  File _configFile = File('');

  /// Конфигурация
  Map<String, dynamic> config = Map<String, dynamic>();
  static Map<String, dynamic> _getConfig(File file) {
    var res = Map<String, dynamic>();
    if (file.existsSync()) {
      if (file.path.endsWith('json')) {
        return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
      }
      var lines = file.readAsLinesSync();
      lines.forEach((e) {
        res[e.substring(0, e.indexOf(':')).trim()] = e.substring(e.indexOf(':') + 1).trim();
      });
    }
    return res;
  }

  Uri? get serverUri {
    if (config.isNotEmpty && config.containsKey('serverUri')) {
      return Uri.tryParse(config['serverUri']);
    }
    return null;
  }

  NsgDataOptions({configPath = 'config.txt'}) {
    if (!kIsWeb) this.configPath = configPath;
  }

  static NsgDataOptions instance = NsgDataOptions();
}
