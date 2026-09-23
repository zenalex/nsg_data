// Разводка ответа 401 из сетевого слоя в хук истёкшей сессии.
//
// Файл лежит в `lib/src`: по соглашению Dart это внутренности пакета, из
// `nsg_data.dart` он не экспортируется. Публичная часть — только хук
// `NsgApiException.onSessionExpired`; пока он не задан, пакет ведёт себя как
// до правки.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nsg_data/nsgApiException.dart';

/// Отказ сервера по авторизации (401) доходит до хука истёкшей сессии.
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
/// ## Почему отдельный хук, а не `showExceptionDefault`
///
/// `showExceptionDefault` в nsg_controls — `NsgErrorWidget.showError`, диалог
/// «ERROR 401». Отдать туда 401 загрузки значило бы поменять поведение всех
/// NSG-приложений, которые своего обработчика сессии не ставили. Поэтому хук
/// отдельный и по умолчанию выключен.
///
/// ## Когда хук НЕ зовётся
///
///  * токен пустой или сессия анонимная: истекать нечему — это не «сессия
///    пользователя кончилась», а отказ анонимному доступу;
///  * запрос ушёл с токеном, который уже не текущий: той сессии уже нет, и о
///    текущей такой ответ ничего не говорит. Иначе запоздавший ответ разлогинил
///    бы сессию, заведённую уже ПОСЛЕ обработки первого 401. Раз токен тот же —
///    и сессия та же, поэтому флаг `isAnonymous` в момент ответа относится к ней;
///  * 401 того же токена в пределах [burstWindow] после предыдущего: протухшая
///    сессия роняет пачку запросов экрана, а хук нужен один раз.
class NsgUnauthorizedDispatch {
  NsgUnauthorizedDispatch._();

  /// Окно, в котором 401 одной сессии считаются одной пачкой.
  static const Duration burstWindow = Duration(seconds: 10);

  /// Источник времени. Подменяется ТОЛЬКО в тестах.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Исключения, которые прошли через хук: отданы в него или погашены как
  /// повтор пачки, которую хук уже получил.
  static final Expando<bool> _routed = Expando<bool>('nsgUnauthorizedRouted');

  static String? _lastToken;
  static DateTime? _lastAt;

  /// `true`, если 401 уже обработан хуком [NsgApiException.onSessionExpired].
  /// Верхний слой (`itemPagePost`) по этому признаку не показывает тот же 401
  /// вторым путём. Без хука всегда `false`.
  static bool isRouted(NsgApiException ex) => _routed[ex] ?? false;

  /// Отдать 401 в [NsgApiException.onSessionExpired], если он задан.
  ///
  /// [sentToken] — токен, с которым ушёл запрос; [currentToken] и [isAnonymous] —
  /// состояние провайдера в момент ответа. Сбой самого хука — синхронный или в
  /// возвращённом им Future — не подменяет 401 и не становится необработанной
  /// ошибкой.
  static void route(
    NsgApiException ex, {
    required String sentToken,
    required String currentToken,
    required bool isAnonymous,
  }) {
    final hook = NsgApiException.onSessionExpired;
    if (hook == null) return;
    if (sentToken.isEmpty) return;

    if (sentToken != currentToken) {
      debugPrint('[nsg_data] 401 на запрос прежней сессии — текущую не трогаем');
      return;
    }
    if (isAnonymous) return;

    _routed[ex] = true;
    final now = clock();
    final lastAt = _lastAt;
    if (_lastToken == sentToken && lastAt != null && now.difference(lastAt) < burstWindow) {
      return;
    }
    _lastToken = sentToken;
    _lastAt = now;

    try {
      final result = hook(ex);
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
