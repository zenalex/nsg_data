// Правила межвкладочного обмена токеном — NSG-SOFT/futbolista-tasks#1496.
//
// Повод. Тренер регистрировался по пригласительной ссылке: вход проходил,
// EULA подписывалась, и сразу после «Adopting token from other tab» сервер
// переставал отдавать пользователя, а человек получал «Ошибка авторизации!».
// Причина — колбэк обмена безусловно гасил токен, когда соседняя вкладка
// присылала null. То есть чужой логаут разлогинивал вкладку, в которой прямо
// сейчас регистрировались.
//
// Тесты держат ровно одно правило: обмен между вкладками не имеет права
// ПОНИЖАТЬ аутентификацию этой вкладки.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Провайдеру нужны обязательные параметры конструктора; для правил обмена
/// токеном они роли не играют, поэтому подставляем заглушки.
NsgDataProvider _provider() => NsgDataProvider(
      applicationName: 'test',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams(const <String, String>{}, ''),
    );

NsgDataProvider _authorized({String token = 'live-token'}) {
  final p = _provider();
  p.token = token;
  p.isAnonymous = false;
  return p;
}

NsgDataProvider _anonymous() {
  final p = _provider();
  p.token = '';
  p.isAnonymous = true;
  return p;
}

void main() {
  group('чужой логаут', () {
    test('НЕ гасит вкладку с живой сессией — это и был баг #1496', () {
      final p = _authorized();

      final changed = p.applyCrossTabToken(null);

      expect(changed, isFalse, reason: 'состояние меняться не должно');
      expect(p.token, 'live-token', reason: 'токен вкладки обязан уцелеть');
      expect(p.isAnonymous, isFalse, reason: 'вкладка остаётся авторизованной');
    });

    test('пустая строка от соседа — то же самое, что null', () {
      final p = _authorized();

      expect(p.applyCrossTabToken(''), isFalse);
      expect(p.token, 'live-token');
      expect(p.isAnonymous, isFalse);
    });

    test('анонимную вкладку повторный null не трогает (не событие)', () {
      final p = _anonymous();

      expect(p.applyCrossTabToken(null), isFalse, reason: 'менять нечего');
      expect(p.token, isEmpty);
      expect(p.isAnonymous, isTrue);
    });
  });

  group('принятие чужого токена', () {
    test('анонимная вкладка принимает токен соседа — ради этого обмен и нужен', () {
      final p = _anonymous();

      final changed = p.applyCrossTabToken('token-from-peer');

      expect(changed, isTrue);
      expect(p.token, 'token-from-peer');
      expect(p.isAnonymous, isFalse);
    });

    test('тот же самый токен — не событие', () {
      final p = _authorized(token: 'same');

      expect(p.applyCrossTabToken('same'), isFalse,
          reason: 'иначе каждый ответ соседа = лишняя запись в хранилище и уведомление');
      expect(p.token, 'same');
    });

    test('другой непустой токен принимается и считается сменой', () {
      final p = _authorized(token: 'old');

      final changed = p.applyCrossTabToken('new');

      expect(changed, isTrue, reason: 'смена личности сессии обязана быть наблюдаемой');
      expect(p.token, 'new');
      expect(p.isAnonymous, isFalse);
    });

    test('токен поднимает анонимную вкладку, даже если строка совпала с пустой', () {
      final p = _anonymous();
      p.token = 'stale';

      expect(p.applyCrossTabToken('stale'), isTrue,
          reason: 'isAnonymous ещё true — состояние меняется, несмотря на равенство строк');
      expect(p.isAnonymous, isFalse);
    });
  });

  group('сценарий из задачи целиком', () {
    test('регистрация переживает логаут в соседней вкладке', () {
      // вкладка А: человек только что зарегистрировался
      final registrationTab = _authorized(token: 'just-registered');

      // вкладка Б разлогинилась и разослала null
      registrationTab.applyCrossTabToken(null);

      // до фикса здесь были '' и true → сервер не отдавал пользователя,
      // _resolveDocumentOwner возвращал null, и человек видел
      // «Ошибка авторизации!» на последнем шаге регистрации
      expect(registrationTab.token, 'just-registered');
      expect(registrationTab.isAnonymous, isFalse);
    });
  });
}
