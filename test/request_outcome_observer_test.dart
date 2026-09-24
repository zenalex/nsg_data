import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// NSG-SOFT/futbolista-tasks#2279: наблюдатель исходов запросов — единственный
/// способ для приложения узнать «сервер отвечает» по любому запросу.
void main() {
  late HttpServer server;
  late String baseUrl;
  late NsgDataProvider provider;
  final outcomes = <NsgRequestOutcome>[];

  setUp(() async {
    outcomes.clear();
    NsgRequestOutcome.observer = outcomes.add;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final status = int.parse(request.uri.queryParameters['status'] ?? '200');
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(status == 200 ? {'ok': true} : {'message': 'refused'}));
      await request.response.close();
    });
    baseUrl = 'http://${InternetAddress.loopbackIPv4.address}:${server.port}';
    provider = NsgDataProvider(
      applicationName: 'test_app',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams({baseUrl: 'main'}, baseUrl),
    )..serverUri = baseUrl;
  });

  tearDown(() async {
    NsgRequestOutcome.observer = null;
    await server.close(force: true);
  });

  test('успешный ответ — исход со статусом и адресом без строки запроса', () async {
    await provider.baseRequestList(url: '$baseUrl/Api/Match/Get?status=200&token=secret', function: 'Get');
    expect(outcomes, hasLength(1));
    expect(outcomes.single.statusCode, 200);
    expect(outcomes.single.serverReachable, isTrue);
    expect(outcomes.single.url, '$baseUrl/Api/Match/Get');
    expect(outcomes.single.function, 'Get');
  });

  test('отказ по существу — сервер ответил, исход сообщается, исключение прежнее', () async {
    await expectLater(
      provider.baseRequestList(url: '$baseUrl/x?status=400'),
      throwsA(isA<NsgApiException>().having((e) => e.error.code, 'code', 400)),
    );
    expect(outcomes.single.statusCode, 400);
    expect(outcomes.single.serverReachable, isTrue);
  });

  test('5xx — ответ есть, но сервер недоступен', () async {
    await expectLater(provider.baseRequestList(url: '$baseUrl/x?status=502'), throwsA(isA<NsgApiException>()));
    expect(outcomes.single.hasResponse, isTrue);
    expect(outcomes.single.serverReachable, isFalse);
  });

  test('нет ответа — исход без статуса, с типом ошибки dio', () async {
    final port = server.port;
    await server.close(force: true);
    await expectLater(
      provider.baseRequestList(url: 'http://${InternetAddress.loopbackIPv4.address}:$port/x'),
      throwsA(isA<NsgApiException>()),
    );
    expect(outcomes.single.hasResponse, isFalse);
    expect(outcomes.single.errorType, DioExceptionType.connectionError);
  });

  test('baseRequest и imageRequest тоже сообщают исход', () async {
    await provider.baseRequest(url: '$baseUrl/y?status=200');
    await provider.imageRequest(url: '$baseUrl/z?status=200');
    expect(outcomes.map((o) => o.statusCode), [200, 200]);
  });

  test('сбой наблюдателя запрос не ломает', () async {
    NsgRequestOutcome.observer = (_) => throw StateError('observer bug');
    final data = await provider.baseRequestList(url: '$baseUrl/x?status=200');
    expect(data, {'ok': true});
  });
}
