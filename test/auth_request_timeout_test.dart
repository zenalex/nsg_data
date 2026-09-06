import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Регресс на NSG-SOFT/futbolista-tasks#1822.
///
/// Запросы авторизации уходили в dio с `connectTimeout`/`receiveTimeout` == null,
/// а у dio это задокументировано как «ждать без ограничения». Сервер, который
/// принял соединение и не ответил (голодание пула потоков — штатная авария на
/// проде), вешал запуск приложения: замерено до 3005 с. Повтора не происходило
/// ни разу — `RetryOptions` повторяет по исключению, а зависший future его не
/// бросает, так что `autoRepeate` был бесполезен по построению.
void main() {
  late HttpServer server;
  late NsgDataProvider provider;

  setUp(() async {
    // Принимаем соединение и молчим — ровно то, что делает перегруженный сервер.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) {/* ответа не будет */});

    final url = 'http://127.0.0.1:${server.port}';
    provider = NsgDataProvider(
      applicationName: 'test_app',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams({url: 'main'}, url),
    );
    provider.serverUri = url;
    // Секунда вместо пятнадцати — тест про наличие предела, а не про его размер.
    provider.authRequestDuration = 1000;
  });

  tearDown(() async => server.close(force: true));

  test('setLocale не ждёт молчащий сервер вечно', () async {
    final sw = Stopwatch()..start();

    // Внешний timeout — только страховка теста: если предел вернётся к null,
    // здесь будет TimeoutException вместо вечного зависания прогона.
    final code = await provider.setLocale(languageCode: 'ru').timeout(
          const Duration(seconds: 20),
          onTimeout: () => fail('setLocale не завершился за 20 с — предел ожидания снова потерян'),
        );

    expect(code, 0, reason: 'сетевой отказ метод проглатывает, старт едет дальше');
    expect(sw.elapsed.inSeconds, lessThan(15),
        reason: 'уложились в собственный бюджет, а не в страховку теста');
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('baseRequest БЕЗ явного timeout всё равно ограничен', () async {
    // Отдельно от вызовов авторизации: те бюджет передают сами. Здесь проверяем
    // умолчание самого _baseRequest — до фикса `timeout: null` уходил в dio как
    // есть и означал «ждать без ограничения», а таких вызовов в классе много
    // (входы, регистрация, Logout).
    provider.connectDuration = 1000;
    provider.requestDuration = 1000;
    final sw = Stopwatch()..start();

    var threw = false;
    try {
      await provider
          .baseRequest(
            function: 'PhoneLoginRequestSMS',
            headers: provider.getAuthorizationHeader(),
            url: '${provider.serverUri}/Api/Auth/PhoneLoginRequestSMS',
            method: 'GET',
            params: <String, dynamic>{},
            // timeout НЕ передаём — ровно так это делает почти весь класс.
          )
          .timeout(const Duration(seconds: 20),
              onTimeout: () => fail('запрос без явного timeout снова ждёт без ограничения'));
    } on NsgApiException {
      threw = true;
    }

    expect(threw, isTrue);
    expect(sw.elapsed.inSeconds, lessThan(15), reason: 'сработало умолчание, а не страховка теста');
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('CheckToken отваливается по бюджету и повторяет попытки', () async {
    provider.token = 'stale-token';
    final sw = Stopwatch()..start();

    // connect() дойдёт до _checkToken; тот повторяется autoRepeateCount раз.
    // Нам важно только, что каждая попытка ОГРАНИЧЕНА: без этого первая же
    // висела бы бесконечно и до второй дело не доходило никогда.
    var threw = false;
    try {
      await provider
          .baseRequest(
            function: 'CheckToken',
            headers: provider.getAuthorizationHeader(),
            url: '${provider.serverUri}/Api/Auth/CheckToken',
            method: 'GET',
            params: <String, dynamic>{},
            timeout: provider.authRequestTimeout,
            autoRepeate: true,
            autoRepeateCount: 3,
          )
          .timeout(const Duration(seconds: 25), onTimeout: () => fail('попытки не ограничены по времени'));
    } on NsgApiException {
      threw = true;
    }

    expect(threw, isTrue, reason: 'после исчерпания попыток запрос обязан упасть, а не висеть');
    expect(sw.elapsed.inSeconds, greaterThanOrEqualTo(3),
        reason: 'три попытки по секунде — значит повторы реально состоялись');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
