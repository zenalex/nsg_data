// Токен на устройстве и его сброс при выходе.
//
// Найдено по NSG-SOFT/futbolista-tasks#1836: офлайн-старт решает «человек
// вошёл?» по сохранённому токену, поэтому токен, переживший выход, там —
// прямая дыра. Проверка показала, что выход НЕ удалял сохранённый токен вообще,
// причём по трём независимым причинам — и починка любой одной не помогала:
//
//  1. save/get пишут под ключ ГРУППЫ серверов (`<app>_SERVER_URL_main`), а
//     resetCurrentServerToken удалял ключ с АДРЕСОМ сервера
//     (`<app>_SERVER_URL_https://…`), который никто никогда не писал;
//  2. logout()/resetUserToken() звали resetCurrentServerToken() без await и
//     сразу чистили token в памяти, а reset после своего первого await
//     проверял `token.isEmpty` и выходил, ничего не удалив — даже с верным
//     ключом;
//  3. ключ старого формата `<app>` не удалялся, хотя initialize() читает его
//     запасным, а клиент (openLoginPage на Windows и по диплинку) до сих пор
//     в него пишет.
//
// Итог: следующий холодный старт поднимал отозванный токен и слал его в
// CheckToken.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _app = 'test_app';

// Боевая группа — два адреса, как у клиента (.me и .ru, между ними
// переключает ServerFailover), плюс отдельная тестовая группа.
const _me = 'https://data1.example.me';
const _ru = 'https://data1.example.ru';
const _test = 'https://test.example.me:5077';

// Формат ключа — контракт с уже установленными приложениями: поменяешь его —
// у всех пользователей «пропадёт» вход. Поэтому здесь литералы, а не вызов
// того же кода, что пишет ключ.
const _mainKey = '${_app}_SERVER_URL_main';
const _testKey = '${_app}_SERVER_URL_test';

// Ключ старого формата: так токен хранился до разделения по группам серверов.
const _legacyKey = _app;

NsgDataProvider _provider({String current = _me, Map<String, String>? groups}) => NsgDataProvider(
      applicationName: _app,
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams(groups ?? {_me: 'main', _ru: 'main', _test: 'test'}, current),
      serverUri: current,
    );

Future<NsgDataProvider> _loggedIn({String token = 'user-token', String current = _me, Map<String, String>? groups}) async {
  final p = _provider(current: current, groups: groups);
  p.token = token;
  p.isAnonymous = false;
  await p.saveCurrentServerToken();
  return p;
}

/// Холодный старт: новый провайдер читает хранилище так же, как при запуске.
Future<NsgDataProvider> _coldStart({String current = _me, Map<String, String>? groups}) async {
  final p = _provider(current: current, groups: groups);
  await p.initialize();
  return p;
}

Future<bool> _stored(String key) async => (await SharedPreferences.getInstance()).containsKey(key);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ключ хранения — контракт с установленными приложениями', () {
    test('saveCurrentServerToken пишет под ключ группы, а не адреса', () async {
      await _loggedIn();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_mainKey), 'user-token');
    });

    test('холодный старт поднимает сохранённый токен — вход переживает перезапуск', () async {
      await _loggedIn();

      final p = await _coldStart();

      expect(p.token, 'user-token');
      expect(p.isAnonymous, isFalse);
    });
  });

  group('resetCurrentServerToken', () {
    test('удаляет ровно тот ключ, под которым save сохранил', () async {
      final p = await _loggedIn();

      await p.resetCurrentServerToken();

      expect(await _stored(_mainKey), isFalse,
          reason: 'до фикса удалялся `<app>_SERVER_URL_<адрес>` — ключ, которого никто не писал');
    });

    test('удаляет, даже если токен в памяти уже очищен', () async {
      final p = await _loggedIn();
      p.token = '';

      await p.resetCurrentServerToken();

      expect(await _stored(_mainKey), isFalse,
          reason: 'сброс хранилища не зависит от того, что лежит в памяти: вызывающие чистят token сами');
    });

    test('токен общий для адресов группы: вход на .me, выход после переключения на .ru', () async {
      final p = await _loggedIn(current: _me);
      p.availableServers.currentServer = _ru; // ServerFailover сменил адрес между входом и выходом

      await p.resetCurrentServerToken();

      expect(await _stored(_mainKey), isFalse);
    });

    test('чистит ключ старого формата — initialize() читает его запасным', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{_legacyKey: 'legacy-token'});
      final p = _provider();

      await p.resetCurrentServerToken();

      expect(await _stored(_legacyKey), isFalse);
    });

    test('токен другой группы серверов не трогает', () async {
      await _loggedIn(token: 'test-token', current: _test);
      final p = await _loggedIn(token: 'main-token', current: _me);

      await p.resetCurrentServerToken();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(_mainKey), isFalse);
      expect(prefs.getString(_testKey), 'test-token', reason: 'выход с боевого сервера не выкидывает из тестового');
    });
  });

  group('resetUserToken', () {
    test('к моменту завершения сохранённого токена уже нет', () async {
      final p = await _loggedIn();

      await p.resetUserToken();

      expect(await _stored(_mainKey), isFalse,
          reason: 'до фикса reset звался без await и видел уже очищенный token — выходил, ничего не удалив');
      expect(p.token, isEmpty);
      expect(p.isAnonymous, isTrue);
    });

    test('следующий холодный старт — анонимный, в том числе через ключ старого формата', () async {
      // Клиент на Windows и по диплинку сохраняет токен ещё и под `<app>`.
      SharedPreferences.setMockInitialValues(<String, Object>{_legacyKey: 'user-token'});
      final p = await _loggedIn();

      await p.resetUserToken();

      final cold = await _coldStart();
      expect(cold.token, isEmpty);
      expect(cold.isAnonymous, isTrue);
    });
  });

  group('logout() целиком — путь кнопки «Выйти» и SessionGuard', () {
    late HttpServer server;
    late String url;
    late List<String> hits;

    setUp(() async {
      hits = <String>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      url = 'http://127.0.0.1:${server.port}';
      server.listen((HttpRequest request) async {
        hits.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write(request.uri.path.endsWith('/AnonymousLogin')
            ? jsonEncode(<String, Object>{'token': 'anonymous-token', 'isAnonymous': true, 'errorCode': 0})
            : '{}');
        await request.response.close();
      });
    });

    tearDown(() async => server.close(force: true));

    test('после выхода токена нет ни под одним ключом, холодный старт анонимный', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{_legacyKey: 'user-token'});
      final groups = {url: 'main'};
      final p = await _loggedIn(current: url, groups: groups);

      await p.logout(NsgBaseController());

      expect(hits, contains('/Api/Auth/Logout'), reason: 'сервер отзывает токен — значит хранить его дальше незачем');
      expect(await _stored(_mainKey), isFalse);
      expect(await _stored(_legacyKey), isFalse);
      expect(p.isAnonymous, isTrue);

      final cold = await _coldStart(current: url, groups: groups);
      expect(cold.token, isEmpty, reason: 'до фикса старт поднимал отозванный токен и слал его в CheckToken');
      expect(cold.isAnonymous, isTrue);
    });

    test('чистит хранилище, даже если сессия в памяти уже анонимная', () async {
      // Например, CheckToken на старте понизил сессию до анонимной, а
      // сохранённый токен остался. Выход обязан его забыть.
      final groups = {url: 'main'};
      final p = await _loggedIn(current: url, groups: groups);
      p.token = 'anonymous-token';
      p.isAnonymous = true;

      await p.logout(NsgBaseController());

      expect(await _stored(_mainKey), isFalse);
    });
  });
}
