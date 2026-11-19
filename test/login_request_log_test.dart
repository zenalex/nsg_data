import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Регресс на NSG-SOFT/futbolista-tasks#4892.
///
/// baseRequest печатал params входа без условий. debugPrint в релизе — это
/// console.log и лог устройства, а в params лежат пароль, код и newPassword.
void main() {
  const password = 'pw-sentinel-4892-alpha';
  const code = 'code-sentinel-4892-beta';
  const newPassword = 'np-sentinel-4892-gamma';
  const token = 'tok-sentinel-4892-delta';
  const querySecret = 'q-sentinel-4892-epsilon';
  const bodySecret = 'body-sentinel-4892-zeta';

  late HttpServer server;
  late NsgDataProvider provider;
  late List<String> logs;
  late List<String> received;
  late DebugPrintCallback previousDebugPrint;

  setUp(() async {
    logs = <String>[];
    received = <String>[];
    previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      received.add(await utf8.decoder.bind(request).join());
      final path = request.uri.path;
      request.response.headers.contentType = ContentType.json;
      if (path.endsWith('PhoneLoginRequestGoogle')) {
        request.response.statusCode = 403;
        request.response.write(jsonEncode({'message': bodySecret}));
      } else {
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'errorCode': 1,
            'isError': true,
            'isAnonymous': true,
            'errorMessage': '',
            'token': '',
          }),
        );
      }
      await request.response.close();
    });

    final url = 'http://127.0.0.1:${server.port}';
    provider = NsgDataProvider(
      applicationName: 'test_app',
      applicationVersion: '1.0.0',
      firebaseToken: '',
      availableServers: NsgServerParams({url: 'main'}, url),
    );
    provider.serverUri = url;
    provider.token = token;
    provider.saveToken = false;
  });

  tearDown(() async {
    debugPrint = previousDebugPrint;
    await server.close(force: true);
  });

  test(
    'PhoneLogin и phoneLoginPassword не печатают пароль, код и newPassword',
    () async {
      expect(kDebugMode, isTrue);

      final login = await provider.phoneLogin(
        phoneNumber: 'login-name-4892',
        securityCode: code,
        newPassword: newPassword,
      );
      expect(login.errorCode, 1);

      final byPassword = await provider.phoneLoginPassword(
        phoneNumber: 'login-name-4892',
        securityCode: password,
      );
      expect(byPassword.errorCode, 1);

      final withQuery = await provider.baseRequest(
        function: 'PhoneLogin',
        headers: provider.getAuthorizationHeader(),
        url: '${provider.serverUri}/Api/Auth/PhoneLogin?drop=$querySecret',
        method: 'POST',
        params: <String, dynamic>{
          'securityCode': password,
          'newPassword': newPassword,
        },
      );
      expect(withQuery?['errorCode'], 1);

      final social = await provider.requestSocialMethod(
        function: 'PhoneLoginRequestGoogle',
        methodName: 'PhoneLoginRequestGoogle',
        params: <String, dynamic>{'securityCode': code},
      );
      expect(social.errorMessage, bodySecret);
      expect(social.errorCode, 403);

      final inbound = received.join('\n');
      expect(inbound, contains(password));
      expect(inbound, contains(code));
      expect(inbound, contains(newPassword));

      final text = logs.join('\n');
      expect(text, isNot(contains(password)));
      expect(text, isNot(contains(code)));
      expect(text, isNot(contains(newPassword)));
      expect(text, isNot(contains(token)));
      expect(text, isNot(contains(querySecret)));
      expect(text, isNot(contains(bodySecret)));
      expect(text, contains('function=PhoneLogin'));
      expect(text, contains('path=/Api/Auth/PhoneLogin'));
      expect(text, isNot(contains('params:')));
      expect(text, contains('status: 403'));
    },
  );
}
