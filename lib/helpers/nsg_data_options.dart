import 'dart:convert';
import 'dart:io';

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
    if (file.existsSync()) {
      if (file.path.endsWith('json')) {
        return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
      }
      return file.readAsLinesSync().map((e) => MapEntry(e.substring(0, e.indexOf(':')).trim(), e.substring(e.indexOf(':') + 1).trim())) as Map<String, dynamic>;
    }
    return Map<String, dynamic>();
  }

  Uri? get serverUri {
    if (config.isNotEmpty && config.containsKey('serverUri')) {
      return Uri.tryParse(config['serverUri']);
    }
    return null;
  }

  NsgDataOptions({configPath = 'config.txt'});

  static NsgDataOptions instance = NsgDataOptions();
}
