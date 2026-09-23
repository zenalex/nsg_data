import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

void main() {
  test('baseRequestList preserves an unhandled HTTP response status', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = 429
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': 'error: 15: Access denied'}));
      await request.response.close();
    });

    final baseUrl =
        'http://${InternetAddress.loopbackIPv4.address}:${server.port}';
    final provider = NsgDataProvider(
      applicationName: 'test_app',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams({baseUrl: 'main'}, baseUrl),
    )..serverUri = baseUrl;

    await expectLater(
      provider.baseRequestList(url: '$baseUrl/test', method: 'GET'),
      throwsA(
        isA<NsgApiException>()
            .having((error) => error.error.code, 'HTTP status', 429)
            .having(
              (error) => error.error.message,
              'server message',
              'error: 15: Access denied',
            ),
      ),
    );
  });
}
