import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

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
    debugPrint('[CrossTabAuth] init() вызван для канала: $channelName, scope: $scope');

    try {
      _channel = web.BroadcastChannel(channelName);
      debugPrint('[CrossTabAuth] BroadcastChannel создан успешно');

      _bcListener = ((web.Event e) {
        debugPrint('[CrossTabAuth] Получено сообщение через BroadcastChannel');
        final me = e as web.MessageEvent;
        final raw = _stringFromJsAny(me.data);
        if (raw != null && raw.isNotEmpty) {
          debugPrint('[CrossTabAuth] Обработка сообщения BroadcastChannel: $raw');
          _handleMessageString(raw);
        } else {
          debugPrint('[CrossTabAuth] Пустое или null сообщение BroadcastChannel');
        }
      }).toJS;
      _channel!.addEventListener('message', _bcListener!);
      debugPrint('[CrossTabAuth] Слушатель BroadcastChannel добавлен');
    } catch (e) {
      debugPrint('[CrossTabAuth] Ошибка создания BroadcastChannel: $e');
      _channel = null;
    }

    _lsListener = ((web.Event e) {
      debugPrint('[CrossTabAuth] Получено storage событие');
      final se = e as web.StorageEvent;
      final key = se.key;
      final newValue = se.newValue;
      debugPrint('[CrossTabAuth] StorageEvent - key: $key, newValue: ${newValue?.substring(0, 50) ?? 'null'}...');
      if (key == _lsKey && newValue != null) {
        debugPrint('[CrossTabAuth] Обработка storage сообщения: $newValue');
        _handleMessageString(newValue);
      } else {
        debugPrint('[CrossTabAuth] StorageEvent проигнорирован (key != _lsKey или newValue == null)');
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
    debugPrint('[CrossTabAuth] publishToken() вызван с токеном длиной: ${token.length}');
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
    debugPrint('[CrossTabAuth] _broadcast() вызван (длина сообщения: ${message.length})');

    if (_channel != null) {
      debugPrint('[CrossTabAuth] Отправка через BroadcastChannel');
      _channel!.postMessage(message.toJS);
      debugPrint('[CrossTabAuth] Сообщение отправлено через BroadcastChannel');
    } else {
      debugPrint('[CrossTabAuth] BroadcastChannel недоступен, сообщение не отправлено через канал');
    }

    debugPrint('[CrossTabAuth] Отправка через localStorage');
    web.window.localStorage.setItem(_lsKey, message);
    web.window.localStorage.removeItem(_lsKey);
    debugPrint('[CrossTabAuth] Сообщение отправлено через localStorage');
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
