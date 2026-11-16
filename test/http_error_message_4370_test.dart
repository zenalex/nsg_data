import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  late NsgDataProvider provider;
  late int status;
  late String body;
  late ContentType contentType;
  late bool hang;
  late int hits;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    status = 403;
    body = '{"message":"Не хватает прав на запись"}';
    contentType = ContentType.json;
    hang = false;
    hits = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      hits++;
      if (hang) {
        await request.drain<void>();
        return;
      }
      request.response
        ..statusCode = status
        ..headers.contentType = contentType
        ..write(body);
      await request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}';
    provider = NsgDataProvider(
      applicationName: 'test',
      applicationVersion: '0',
      firebaseToken: '',
      availableServers: NsgServerParams({url: 'main'}, url),
    );
    await provider.initialize();
    provider.serverUri = url;
  });

  tearDown(() async {
    provider.dispose();
    await server.close(force: true);
  });

  Future<NsgApiException> post() async {
    try {
      await provider.baseRequestList(
        function: 'PlayerItem/Post',
        url: '${provider.serverUri}/Api/PlayerItem/Post',
        method: 'POST',
        postData: const [
          {'id': '1'},
        ],
      );
      fail('сервер отказал, запрос не должен завершиться данными');
    } on NsgApiException catch (e) {
      return e;
    }
  }

  test('403 с телом показывает текст сервера, это не «нет связи»', () async {
    final error = await post();
    expect(error.error.code, 403);
    expect(error.error.message, 'Не хватает прав на запись');
    expect(error.isPermissionError, isTrue);
    expect(error.isNetworkError, isFalse);
  });

  test('403 текстом, не JSON, тоже показывает отказ, а не обрыв связи', () async {
    contentType = ContentType.text;
    body = 'Не хватает прав на запись';
    final error = await post();
    expect(error.error.code, 403);
    expect(error.error.message, 'Не хватает прав на запись');
    expect(error.isNetworkError, isFalse);
  });

  test('422 с телом — текст сервера, не Internet connection error', () async {
    status = 422;
    body = '{"message":"Игрок уже в составе"}';
    final error = await post();
    expect(error.error.code, 422);
    expect(error.error.message, 'Игрок уже в составе');
    expect(error.isNetworkError, isFalse);
    expect(error.error.message, isNot('Internet connection error'));
  });

  test('403 с телом не-JSON и типом application/json — это отказ, не ERROR 1', () async {
    contentType = ContentType('application', 'json', charset: 'utf-8');
    body = 'Не хватает прав на запись';
    final error = await post();
    expect(error.error.code, 403);
    expect(error.error.message, 'Не хватает прав на запись');
    expect(error.isPermissionError, isTrue);
    expect(error.isNetworkError, isFalse);
  });

  test('422 без текста — не «Internet connection error»', () async {
    status = 422;
    body = '';
    final error = await post();
    expect(error.error.code, 422);
    expect(error.isNetworkError, isFalse);
    expect(error.error.message, isNot('Internet connection error'));
  });

  test('таймаут — нет связи, не отказ по правам', () async {
    hang = true;
    provider.requestDuration = 400;
    final error = await post();
    expect(error.error.code, 2);
    expect(error.isNetworkError, isTrue);
    expect(error.isPermissionError, isFalse);
    expect(error.error.message, contains('нет связи'));
  });

  test('403 не повторяется и не подменяется обрывом', () async {
    await expectLater(
      NsgSimpleRequest<String>().requestItems(
        provider: provider,
        function: '/Api/PlayerItem/Post',
        method: 'POST',
        autoRepeate: true,
        autoRepeateCount: 4,
      ),
      throwsA(
        isA<NsgApiException>()
            .having((e) => e.error.code, 'code', 403)
            .having((e) => e.error.message, 'message', 'Не хватает прав на запись')
            .having((e) => e.isNetworkError, 'network', false),
      ),
    );
    expect(hits, 1);
  });

  test('код HTTP важнее типа Dio: 403 — не «нет связи»', () {
    final error = NsgApiException(
      NsgApiError(code: 403, message: 'Не хватает прав на запись', errorType: DioExceptionType.connectionError),
    );
    expect(error.isNetworkError, isFalse);
    expect(error.isPermissionError, isTrue);
  });
}
