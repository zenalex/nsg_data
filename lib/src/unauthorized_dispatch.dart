// Разводка ответа 401 из сетевого слоя в обработчик ошибок по умолчанию.
//
// Файл лежит в `lib/src`: по соглашению Dart это внутренности пакета, из
// `nsg_data.dart` он не экспортируется. Публичный API пакета правка не меняет —
// работает только через уже существующий `NsgApiException.showExceptionDefault`.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nsg_data/nsgApiException.dart';

/// Отказ сервера по авторизации (401) доходит до обработчика по умолчанию.
///
/// ## Зачем (NSG-SOFT/futbolista-tasks#176)
///
/// `NsgApiException.showExceptionDefault` пакет вызывал только из
/// `itemPagePost` — то есть при сохранении. Загрузка (`NsgDataRequest`,
/// `NsgSimpleRequest`, `NsgDataFreeRequest`, удаление) получала 401 из
/// `NsgDataProvider.baseRequestList` и просто бросала его вызывающему. Если тот
/// не ловил (запрос из `onInit`, запрос без `await`), исключение становилось
/// необработанным.
///
/// Приложение ловило такой 401 вторым хуком — `PlatformDispatcher.onError`. На
/// вебе это не работает вовсе: веб-движок Flutter значение `onError` хранит, но
/// никогда не вызывает. Необработанная ошибка уходит в `window.onerror`, мимо
/// любого дартового кода. Разбор GT-4619: в стеке `baseRequestList` → асинхронная
/// машинерия → обработчик зоны, и ни одного кадра обработчика сессии.
///
/// Поэтому разводка стоит там, где 401 известен достоверно, — в сетевом слое, до
/// того как исключение уйдёт вверх. Исключение бросается как и раньше: контракт
/// вызывающих не меняется.
///
/// ## Почему не на каждый 401
///
/// Протухшая сессия даёт 401 на КАЖДОМ запросе, а экран обычно шлёт их пачкой.
/// Обработчик по умолчанию из nsg_controls (`NsgErrorWidget.showError`) рисует
/// диалог на каждый вызов, так что без гашения повторов получилась бы стопка
/// диалогов. Поэтому:
///
///  * ответ на запрос, отправленный с токеном, который уже не текущий, в
///    обработчик не идёт: той сессии уже нет, и о текущей такой ответ ничего не
///    говорит. Иначе запоздавший ответ разлогинил бы сессию, заведённую уже ПОСЛЕ
///    обработки первого 401;
///  * 401 одного и того же токена в пределах [burstWindow] доходят один раз.
class NsgUnauthorizedDispatch {
  NsgUnauthorizedDispatch._();

  /// Окно, в котором 401 одной сессии считаются одной пачкой.
  static const Duration burstWindow = Duration(seconds: 10);

  /// Источник времени. Подменяется ТОЛЬКО в тестах.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Исключения, судьбу которых уже решил сетевой слой: отдал в обработчик по
  /// умолчанию или сознательно не отдал (повтор пачки, устаревшая сессия).
  static final Expando<bool> _routed = Expando<bool>('nsgUnauthorizedRouted');

  static String? _lastToken;
  static DateTime? _lastAt;

  /// `true`, если 401 уже прошёл через [route]. Верхний слой по этому признаку не
  /// зовёт тот же обработчик по умолчанию второй раз.
  static bool isRouted(NsgApiException ex) => _routed[ex] ?? false;

  /// Отдать 401 в `NsgApiException.showExceptionDefault`.
  ///
  /// [sentToken] — токен, с которым ушёл запрос; [currentToken] — токен
  /// провайдера в момент ответа. Сбой самого обработчика — синхронный или в
  /// возвращённом им Future — не подменяет 401 и не становится необработанной
  /// ошибкой.
  static void route(NsgApiException ex, {required String sentToken, required String currentToken}) {
    _routed[ex] = true;

    if (sentToken != currentToken) {
      debugPrint('[nsg_data] 401 на запрос прежней сессии — текущую не трогаем');
      return;
    }

    final now = clock();
    final lastAt = _lastAt;
    if (_lastToken == sentToken && lastAt != null && now.difference(lastAt) < burstWindow) {
      return;
    }

    final handler = NsgApiException.showExceptionDefault;
    if (handler == null) return;
    _lastToken = sentToken;
    _lastAt = now;

    try {
      // Тип обработчика — `void Function`, но nsg_controls ставит туда async-функцию.
      // Её Future иначе выбросился бы, и ошибка в нём стала бы необработанной.
      final Object? result = Function.apply(handler, <Object?>[ex]);
      if (result is Future) {
        unawaited(result.then<void>((_) {}, onError: (Object e, StackTrace s) {
          debugPrint('[nsg_data] обработчик 401 упал: $e\n$s');
        }));
      }
    } catch (e, s) {
      debugPrint('[nsg_data] обработчик 401 упал: $e\n$s');
    }
  }

  /// Сбросить состояние между тестами.
  @visibleForTesting
  static void resetForTesting() {
    _lastToken = null;
    _lastAt = null;
    clock = DateTime.now;
  }
}
