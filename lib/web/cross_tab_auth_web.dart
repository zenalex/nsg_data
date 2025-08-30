import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// Получить текущий URL страницы
String getCurrentUrl() {
  return web.window.location.href;
}

// Получить origin (протокол + домен + порт)
String getCurrentOrigin() {
  return web.window.location.origin;
}

// Получить hostname (домен)
String getCurrentHostname() {
  return web.window.location.hostname;
}

// Получить pathname (путь после домена)
String getCurrentPathname() {
  return web.window.location.pathname;
}

// Получить search параметры (?param1=value1&param2=value2)
String getCurrentSearch() {
  return web.window.location.search;
}

// Получить hash (#anchor)
String getCurrentHash() {
  return web.window.location.hash;
}

// Получить referrer (откуда пришли)
String getReferrer() {
  return web.document.referrer;
}

// Проверить, является ли URL безопасным (HTTPS)
bool isSecureUrl() {
  return web.window.location.protocol == 'https:';
}

// Получить полный URL без параметров
String getBaseUrl() {
  final location = web.window.location;
  return '${location.protocol}//${location.host}${location.pathname}';
}

// Пример использования всех функций
void printUrlInfo() {
  debugPrint('=== ИНФОРМАЦИЯ О URL ===');
  debugPrint('Полный URL: ${getCurrentUrl()}');
  debugPrint('Origin: ${getCurrentOrigin()}');
  debugPrint('Hostname: ${getCurrentHostname()}');
  debugPrint('Pathname: ${getCurrentPathname()}');
  debugPrint('Search: ${getCurrentSearch()}');
  debugPrint('Hash: ${getCurrentHash()}');
  debugPrint('Referrer: ${getReferrer()}');
  debugPrint('Безопасный (HTTPS): ${isSecureUrl()}');
  debugPrint('Base URL: ${getBaseUrl()}');
  debugPrint('========================');
}

// Класс для работы с URL параметрами
class UrlParams {
  static Map<String, String> getQueryParameters() {
    final search = getCurrentSearch();
    if (search.isEmpty || !search.startsWith('?')) return {};

    final params = <String, String>{};
    final query = search.substring(1); // Убираем '?'
    final pairs = query.split('&');

    for (final pair in pairs) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        final key = Uri.decodeComponent(parts[0]);
        final value = Uri.decodeComponent(parts[1]);
        params[key] = value;
      }
    }

    return params;
  }

  static String? getQueryParameter(String key) {
    return getQueryParameters()[key];
  }

  static bool hasQueryParameter(String key) {
    return getQueryParameters().containsKey(key);
  }
}

// Пример использования:
// void exampleUsage() {
//   // Получить текущий URL
//   final currentUrl = getCurrentUrl();
//   print('Текущий URL: $currentUrl');
//
//   // Проверить, безопасное ли соединение
//   final isSecure = isSecureUrl();
//   print('HTTPS: $isSecure');
//
//   // Получить параметры из URL
//   final params = UrlParams.getQueryParameters();
//   final userId = UrlParams.getQueryParameter('userId');
//   print('Параметры: $params');
//   print('User ID: $userId');
//
//   // Получить referrer
//   final referrer = getReferrer();
//   print('Пришли с: $referrer');
// }

/// Веб-реализация: синхронизация кратковременного токена аутентификации между вкладками через BroadcastChannel
class CrossTabAuth {
  final String channelName;
  // Дополнительная область видимости для различения приложений/сред (например, serverUri)
  final String scope;

  web.BroadcastChannel? _channel;
  JSFunction? _bcListener;
  JSFunction? _lsListener;

  String? _token;

  final void Function(String? token) onTokenChanged;
  final String? Function() getCurrentToken;

  CrossTabAuth({required this.channelName, required this.scope, required this.onTokenChanged, required this.getCurrentToken});

  static const _evSet = 'auth:set';
  static const _evReq = 'auth:req';
  static const _evLogout = 'auth:logout';

  late final String _lsKey = '__auth_broadcast__:$channelName';

  Future<void> init() async {
    debugPrint('[CrossTabAuth] [INIT] init() вызван для канала: $channelName, scope: $scope, время: ${DateTime.now().toIso8601String()}');
    debugPrint('[CrossTabAuth] [INIT] Текущий origin: ${web.window.location.origin}');
    debugPrint('[CrossTabAuth] [INIT] localStorage key: $_lsKey');
    debugPrint('[CrossTabAuth] [INIT] Проверка localStorage: ${web.window.localStorage.getItem(_lsKey) ?? 'null'}');

    // Показываем полную информацию о URL
    printUrlInfo();

    // Проверяем cross-origin возможности
    try {
      final testOrigin = web.window.location.origin;
      debugPrint('[CrossTabAuth] [INIT] Cross-origin test - origin: $testOrigin');
      debugPrint('[CrossTabAuth] [INIT] ⚠️  ВАЖНО: Все вкладки должны использовать одинаковый origin для работы CrossTabAuth');
      debugPrint('[CrossTabAuth] [INIT] 💡 Рекомендация: Используйте один домен для всех вкладок приложения');
    } catch (e) {
      debugPrint('[CrossTabAuth] [INIT] Ошибка проверки origin: $e');
    }

    // Тестируем localStorage
    try {
      final testKey = '${_lsKey}_test';
      final testValue = 'test_value_${DateTime.now().millisecondsSinceEpoch}';
      web.window.localStorage.setItem(testKey, testValue);
      final readValue = web.window.localStorage.getItem(testKey);
      web.window.localStorage.removeItem(testKey);
      debugPrint('[CrossTabAuth] [TEST] localStorage тест: записано=$testValue, прочитано=$readValue, успех=${testValue == readValue}');
    } catch (e) {
      debugPrint('[CrossTabAuth] [TEST] Ошибка тестирования localStorage: $e');
    }

    try {
      _channel = web.BroadcastChannel(channelName);
      debugPrint('[CrossTabAuth] BroadcastChannel создан успешно');

      _bcListener = ((web.Event e) {
        debugPrint('[CrossTabAuth] [BC] Получено сообщение через BroadcastChannel');
        try {
          final me = e as web.MessageEvent;
          final currentOrigin = web.window.location.origin;
          debugPrint('[CrossTabAuth] [BC] MessageEvent получен, origin: ${me.origin}, current origin: $currentOrigin, source: ${me.source}');

          if (me.origin != currentOrigin) {
            debugPrint('[CrossTabAuth] [BC] ⚠️  CROSS-ORIGIN: Сообщение от другого origin (${me.origin} != $currentOrigin)');
            debugPrint('[CrossTabAuth] [BC] 💡 BroadcastChannel не работает между разными origins');
          }

          final raw = _stringFromJsAny(me.data);
          if (raw != null && raw.isNotEmpty) {
            if (raw.startsWith('test:')) {
              debugPrint('[CrossTabAuth] [BC] Получено тестовое сообщение (длина: ${raw.length})');
            } else {
              debugPrint('[CrossTabAuth] [BC] Обработка сообщения (длина: ${raw.length})');
              _handleMessageString(raw);
            }
          } else {
            debugPrint('[CrossTabAuth] [BC] Пустое или null сообщение');
          }
        } catch (error) {
          debugPrint('[CrossTabAuth] [BC] Ошибка при обработке сообщения: $error');
        }
      }).toJS;
      _channel!.addEventListener('message', _bcListener!);
      debugPrint('[CrossTabAuth] Слушатель BroadcastChannel добавлен');

      // Тестируем BroadcastChannel
      try {
        final testMessage = 'test:${DateTime.now().millisecondsSinceEpoch}';
        _channel!.postMessage(testMessage.toJS);
        debugPrint('[CrossTabAuth] [TEST] Тестовое сообщение BroadcastChannel отправлено: $testMessage');
      } catch (e) {
        debugPrint('[CrossTabAuth] [TEST] Ошибка отправки тестового сообщения BroadcastChannel: $e');
      }
    } catch (e) {
      debugPrint('[CrossTabAuth] Ошибка создания BroadcastChannel: $e');
      _channel = null;
    }

    _lsListener = ((web.Event e) {
      debugPrint('[CrossTabAuth] [LS] Получено storage событие');
      try {
        final se = e as web.StorageEvent;
        final key = se.key;
        final oldValue = se.oldValue;
        final newValue = se.newValue;
        final url = se.url;
        debugPrint('[CrossTabAuth] [LS] StorageEvent - key: $key, url: $url');
        final oldLen = oldValue?.length ?? 0;
        final newLen = newValue?.length ?? 0;
        debugPrint('[CrossTabAuth] [LS] oldValue length: $oldLen, newValue length: $newLen');

        if (key != _lsKey) {
          debugPrint('[CrossTabAuth] [LS] Игнор: ключ отличается (_lsKey=$_lsKey)');
          return;
        }
        if (newValue == null) {
          debugPrint('[CrossTabAuth] [LS] Игнор: newValue == null');
          return;
        }
        if (newValue == oldValue) {
          debugPrint('[CrossTabAuth] [LS] Игнор: newValue == oldValue');
          return;
        }

        debugPrint('[CrossTabAuth] [LS] Обработка storage сообщения (длина: $newLen)');
        _handleMessageString(newValue);
      } catch (error) {
        debugPrint('[CrossTabAuth] [LS] Ошибка при обработке storage события: $error');
      }
    }).toJS;
    web.window.addEventListener('storage', _lsListener!);
    debugPrint('[CrossTabAuth] Слушатель storage добавлен, инициализация завершена');
  }

  void dispose() {
    debugPrint('[CrossTabAuth] dispose() вызван');

    if (_bcListener != null) {
      debugPrint('[CrossTabAuth] Удаление слушателя BroadcastChannel');
      _channel?.removeEventListener('message', _bcListener!);
      _bcListener = null;
    }
    if (_lsListener != null) {
      debugPrint('[CrossTabAuth] Удаление слушателя storage');
      web.window.removeEventListener('storage', _lsListener!);
      _lsListener = null;
    }
    _channel?.close();
    debugPrint('[CrossTabAuth] BroadcastChannel закрыт, dispose завершен');
  }

  void requestTokenFromPeers() {
    debugPrint('[CrossTabAuth] requestTokenFromPeers() вызван');
    final message = _msg(type: _evReq, scope: scope);
    debugPrint('[CrossTabAuth] Запрос токена от других вкладок (type: _evReq, scope: $scope)');
    _broadcast(message);
  }

  void publishToken(String token) {
    debugPrint('[CrossTabAuth] [PUBLISH] publishToken() вызван с токеном длиной: ${token.length}, время: ${DateTime.now().toIso8601String()}');
    _token = token;
    debugPrint('[CrossTabAuth] Токен сохранен локально');
    onTokenChanged(_token);
    debugPrint('[CrossTabAuth] Вызван callback onTokenChanged');
    final message = _msg(type: _evSet, token: token, scope: scope);
    debugPrint('[CrossTabAuth] Публикация токена другим вкладкам (type: _evSet, scope: $scope)');
    _broadcast(message);
  }

  void broadcastLogout() {
    debugPrint('[CrossTabAuth] broadcastLogout() вызван');
    _token = null;
    debugPrint('[CrossTabAuth] Локальный токен очищен');
    onTokenChanged(null);
    debugPrint('[CrossTabAuth] Вызван callback onTokenChanged с null');
    final message = _msg(type: _evLogout, scope: scope);
    debugPrint('[CrossTabAuth] Широковещательный выход (type: _evLogout, scope: $scope)');
    _broadcast(message);
  }

  void _handleMessageString(String raw) {
    debugPrint('[CrossTabAuth] _handleMessageString() вызван (длина сообщения: ${raw.length})');

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
      debugPrint('[CrossTabAuth] JSON успешно распарсен (ключей: ${data.length})');
    } catch (e) {
      debugPrint('[CrossTabAuth] Ошибка парсинга JSON: $e');
      return;
    }

    final type = data['type'] as String?;
    final token = data['token'] as String?;
    final msgScope = data['scope'] as String?;

    debugPrint('[CrossTabAuth] Извлечены данные - type: $type, token: ${token != null ? 'длина=${token.length}' : 'null'}, scope: $msgScope');

    // Игнорировать сообщения для другой области видимости приложения/сервера
    if (msgScope != scope) {
      debugPrint('[CrossTabAuth] Сообщение игнорировано - scope не совпадает (msgScope: $msgScope, currentScope: $scope)');
      return;
    }

    debugPrint('[CrossTabAuth] Обработка сообщения типа: $type');

    switch (type) {
      case _evReq:
        debugPrint('[CrossTabAuth] Обработка запроса токена (_evReq)');
        final mine = getCurrentToken();
        debugPrint('[CrossTabAuth] Текущий токен: ${mine != null ? 'длина=${mine.length}' : 'null'}');
        if (mine != null && mine.isNotEmpty) {
          debugPrint('[CrossTabAuth] Отправка токена в ответ на запрос');
          _broadcast(_msg(type: _evSet, token: mine, scope: scope));
        } else {
          debugPrint('[CrossTabAuth] Токен отсутствует, ответ не отправлен');
        }
        break;
      case _evSet:
        debugPrint('[CrossTabAuth] Обработка установки токена (_evSet)');
        if (token != null && token.isNotEmpty) {
          debugPrint('[CrossTabAuth] Установка нового токена');
          _token = token;
          onTokenChanged(_token);
          debugPrint('[CrossTabAuth] Токен установлен и callback вызван');
        } else {
          debugPrint('[CrossTabAuth] Токен пустой или null, пропуск');
        }
        break;
      case _evLogout:
        debugPrint('[CrossTabAuth] Обработка выхода (_evLogout)');
        _token = null;
        onTokenChanged(null);
        debugPrint('[CrossTabAuth] Выход выполнен, токен очищен');
        break;
      default:
        debugPrint('[CrossTabAuth] Неизвестный тип сообщения: $type');
    }
  }

  void _broadcast(String message) {
    debugPrint('[CrossTabAuth] [BROADCAST] _broadcast() вызван (длина: ${message.length}, канал: $channelName)');

    if (_channel != null) {
      debugPrint('[CrossTabAuth] [BROADCAST] Отправка через BroadcastChannel');
      try {
        _channel!.postMessage(message.toJS);
        debugPrint('[CrossTabAuth] [BROADCAST] Сообщение отправлено через BroadcastChannel успешно');
      } catch (e) {
        debugPrint('[CrossTabAuth] [BROADCAST] Ошибка отправки через BroadcastChannel: $e');
      }
    } else {
      debugPrint('[CrossTabAuth] [BROADCAST] BroadcastChannel недоступен');
    }

    debugPrint('[CrossTabAuth] [BROADCAST] Отправка через localStorage (key: $_lsKey)');
    try {
      final oldValue = web.window.localStorage.getItem(_lsKey);
      web.window.localStorage.setItem(_lsKey, message);
      debugPrint('[CrossTabAuth] [BROADCAST] localStorage.setItem выполнен (старое значение: ${oldValue?.length ?? 0} символов)');
      web.window.localStorage.removeItem(_lsKey);
      debugPrint('[CrossTabAuth] [BROADCAST] localStorage.removeItem выполнен');
    } catch (e) {
      debugPrint('[CrossTabAuth] [BROADCAST] Ошибка работы с localStorage: $e');
    }
  }

  static String _msg({required String type, String? token, String? scope}) {
    final message = jsonEncode({'type': type, if (token != null) 'token': token, if (scope != null) 'scope': scope});
    debugPrint('[CrossTabAuth] _msg() сообщение создано (длина: ${message.length})');
    return message;
  }

  String? _stringFromJsAny(JSAny? any) {
    debugPrint('[CrossTabAuth] _stringFromJsAny() вызван с типом: ${any?.runtimeType ?? 'null'}');

    if (any == null) {
      debugPrint('[CrossTabAuth] _stringFromJsAny() - входной параметр null');
      return null;
    }

    try {
      // Ожидаем JSString, поскольку мы отправляем только строки
      final result = (any as JSString).toDart;
      debugPrint('[CrossTabAuth] _stringFromJsAny() успешно преобразован, длина: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('[CrossTabAuth] _stringFromJsAny() ошибка преобразования: $e');
      return null;
    }
  }
}
