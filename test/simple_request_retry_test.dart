import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// NSG-SOFT/futbolista-tasks#2438: перенос матча в другой турнир показывал
/// «Internet Connection Error», хотя сервер ответил 409 с внятной причиной.
///
/// Повтор из autoRepeate отменял токен предыдущей попытки и тут же брал его же,
/// уже отменённый: вторая и третья попытки падали отменой, не уходя на сервер,
/// и наружу выходила ошибка отмены с запасным текстом «Internet connection error».
void main() {
  test('повтор autoRepeate доходит до сервера, наружу — ответ сервера, а не отмена', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var hits = 0;
    server.listen((request) async {
      hits++;
      request.response
        ..statusCode = 409
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': 'Не удалось согласовать операцию с другими изменениями турнира'}));
      await request.response.close();
    });

    final baseUrl = 'http://${InternetAddress.loopbackIPv4.address}:${server.port}';
    final provider = NsgDataProvider(
      applicationName: 'test_app',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams({baseUrl: 'main'}, baseUrl),
    )..serverUri = baseUrl;

    await expectLater(
      NsgSimpleRequest<String>().requestItems(
        provider: provider,
        function: '/Api/MoveMatchToAnotherTournamentStage',
        method: 'POST',
        autoRepeate: true,
        autoRepeateCount: 3,
      ),
      throwsA(
        isA<NsgApiException>()
            .having((e) => e.error.code, 'HTTP status', 409)
            .having((e) => e.error.message, 'server message', 'Не удалось согласовать операцию с другими изменениями турнира'),
      ),
    );
    expect(hits, 3, reason: 'каждая попытка должна дойти до сервера, а не упасть отменой на клиенте');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
