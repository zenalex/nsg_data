// Правила межвкладочного обмена токеном — NSG-SOFT/futbolista-tasks#1496.
//
// Повод. Тренер регистрировался по пригласительной ссылке: вход проходил,
// EULA подписывалась, и сразу после «Adopting token from other tab» сервер
// переставал отдавать пользователя, а человек получал «Ошибка авторизации!».
//
// ⚠️ ЭТОТ ФАЙЛ ПЕРЕПИСАН ПОСЛЕ СКВОЗНОГО ПРОГОНА В БРАУЗЕРЕ (15.08.2026).
// Первая версия правки запрещала чужому логауту гасить вкладку с живой
// сессией — и прогон показал, что так ХУЖЕ: токен в профиле один на все
// вкладки, логаут отзывает его на сервере, и вкладка оставалась
// «залогиненной» с мёртвым токеном (401 на каждом запросе, без выхода из
// состояния). Правило было верное, но применённое не к той ветке.
//
// Итоговое правило: обмен не подменяет личность ЖИВОЙ вкладки. Чужой токен
// принимается только когда своей сессии нет; чужой логаут гасит, потому что
// сеанс действительно закончился.

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
  group('чужой непустой токен — тот самый путь из #1496', () {
    test('НЕ подменяет личность живой вкладки', () {
      final p = _authorized(token: 'my-session');

      final changed = p.applyCrossTabToken('someone-elses');

      expect(changed, isFalse, reason: 'состояние меняться не должно');
      expect(p.token, 'my-session', reason: 'именно эта подмена и ломала регистрацию');
      expect(p.isAnonymous, isFalse);
    });

    test('анонимная вкладка принимает токен соседа — ради этого обмен и нужен', () {
      final p = _anonymous();

      final changed = p.applyCrossTabToken('token-from-peer');

      expect(changed, isTrue);
      expect(p.token, 'token-from-peer');
      expect(p.isAnonymous, isFalse);
    });

    test('вкладка со стухшим токеном, но анонимная, поднимается чужим токеном', () {
      final p = _anonymous();
      p.token = 'stale';

      expect(p.applyCrossTabToken('fresh'), isTrue,
          reason: 'живой сессии нет, подменять нечего');
      expect(p.token, 'fresh');
      expect(p.isAnonymous, isFalse);
    });

    test('тот же самый токен — не событие', () {
      final p = _authorized(token: 'same');

      expect(p.applyCrossTabToken('same'), isFalse,
          reason: 'иначе каждый ответ соседа = лишняя запись в хранилище и уведомление');
      expect(p.token, 'same');
    });

    test('тот же токен поднимает вкладку, которая числилась анонимной', () {
      final p = _anonymous();
      p.token = 'same';

      expect(p.applyCrossTabToken('same'), isTrue,
          reason: 'строка совпала, но isAnonymous ещё true — состояние меняется');
      expect(p.isAnonymous, isFalse);
    });
  });

  group('чужой логаут гасит вкладку — и это правильно', () {
    test('живая сессия гасится: токен общий и сервер его уже отозвал', () {
      final p = _authorized();

      final changed = p.applyCrossTabToken(null);

      expect(changed, isTrue);
      expect(p.token, isEmpty,
          reason: 'держать отозванный токен = 401 на каждом запросе без выхода из состояния');
      expect(p.isAnonymous, isTrue, reason: 'пользователю показывают вход, а не бесконечные отказы');
    });

    test('пустая строка — то же самое, что null', () {
      final p = _authorized();

      expect(p.applyCrossTabToken(''), isTrue);
      expect(p.token, isEmpty);
      expect(p.isAnonymous, isTrue);
    });

    test('анонимную вкладку повторный null не трогает (не событие)', () {
      final p = _anonymous();

      expect(p.applyCrossTabToken(null), isFalse, reason: 'менять нечего');
      expect(p.token, isEmpty);
      expect(p.isAnonymous, isTrue);
    });
  });

  group('сценарий из задачи целиком', () {
    test('регистрация не теряет свою сессию из-за токена соседней вкладки', () {
      // вкладка А: человек прошёл вход и подписывает EULA
      final registrationTab = _authorized(token: 'just-registered');

      // вкладка Б ответила на auth:req своим токеном — раньше А молча брала его
      // себе, и следующий запрос уходил уже не от того пользователя:
      // passportDoc.sessionUserEmpty → «Ошибка авторизации!»
      registrationTab.applyCrossTabToken('token-of-another-tab');

      expect(registrationTab.token, 'just-registered');
      expect(registrationTab.isAnonymous, isFalse);
    });
  });
}
