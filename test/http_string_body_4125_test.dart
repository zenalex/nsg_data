import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

void main() {
  Future<HttpServer> serve(void Function(HttpRequest request) handle) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      handle(request);
      await request.response.close();
    });
    return server;
  }

  NsgDataProvider providerFor(HttpServer server) {
    final baseUrl = 'http://${InternetAddress.loopbackIPv4.address}:${server.port}';
    return NsgDataProvider(
      applicationName: 'test_app',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams({baseUrl: 'main'}, baseUrl),
    )..serverUri = baseUrl;
  }

  test('400 string body is NsgApiException 400', () async {
    final server = await serve((request) {
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.text
        ..write('upstream refused');
    });
    final provider = providerFor(server);

    await expectLater(
      provider.baseRequestList(url: '${provider.serverUri}/Api/PlayerItem', method: 'POST'),
      throwsA(
        isA<NsgApiException>()
            .having((error) => error.error.code, 'code', 400)
            .having((error) => error.error.message, 'message', 'upstream refused'),
      ),
    );
  });

  test('400 json object message stays NsgApiException', () async {
    final server = await serve((request) {
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': 'filter too large'}));
    });
    final provider = providerFor(server);

    await expectLater(
      provider.baseRequestList(url: '${provider.serverUri}/Api/PlayerItem', method: 'POST'),
      throwsA(
        isA<NsgApiException>()
            .having((error) => error.error.code, 'code', 400)
            .having((error) => error.error.message, 'message', 'filter too large'),
      ),
    );
  });

  test('500 string body is NsgApiException and keeps the tail after separator', () async {
    final server = await serve((request) {
      request.response
        ..statusCode = 500
        ..headers.contentType = ContentType.text
        ..write('Caller ---> detail');
    });
    final provider = providerFor(server);

    await expectLater(
      provider.baseRequestList(url: '${provider.serverUri}/Api/PlayerItem', method: 'POST'),
      throwsA(
        isA<NsgApiException>()
            .having((error) => error.error.code, 'code', 500)
            .having((error) => error.error.message, 'message', 'detail'),
      ),
    );
  });
}
