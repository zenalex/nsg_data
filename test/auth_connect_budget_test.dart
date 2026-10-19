import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Controller extends NsgBaseController {
  _Controller({this.load}) : super(onRetry: (_) async {});
  final Future<void> Function()? load;
  int loads = 0;
  @override
  Future loadProviderData() async { loads++; await load?.call(); }
}

void main() {
  late HttpServer server;
  late NsgDataProvider provider;
  late Map<String, int> hits;
  late Set<String> silent;
  late Map<String, int> statuses;
  late String url;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    hits = {};
    silent = {};
    statuses = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final name = request.uri.pathSegments.last;
      hits.update(name, (n) => n + 1, ifAbsent: () => 1);
      if (silent.contains(name)) return;
      request.response
        ..statusCode = statuses[name] ?? 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'token': 'test-token', 'isAnonymous': false, 'errorCode': 0, 'message': 'test refusal'}));
      await request.response.close();
    });
    url = 'http://127.0.0.1:${server.port}';
    provider = NsgDataProvider(applicationName: 'test', applicationVersion: '0', firebaseToken: '',
      availableServers: NsgServerParams({url: 'main'}, url),
      authConnectDuration: 80, authConnectRetryDelay: 10)
      ..loginRequired = false;
    await provider.initialize();
    provider.token = 'test-token';
  });

  tearDown(() async { provider.dispose(); await server.close(force: true); });

  for (final anonymous in [false, true]) {
    test('${anonymous ? 'AnonymousLogin' : 'CheckToken'}: real connect stops after 3 bounded HTTP attempts', () async {
      final name = anonymous ? 'AnonymousLogin' : 'CheckToken';
      if (anonymous) provider.token = '';
      silent.add(name);
      final controller = _Controller();
      final watch = Stopwatch()..start();
      await expectLater(provider.connect(controller).timeout(const Duration(seconds: 3)),
        throwsA(isA<NsgApiException>().having((e) => e.isNetworkError, 'transport timeout', true)));
      expect(hits[name], 3);
      expect(watch.elapsedMilliseconds, inInclusiveRange(240, 1800));
      expect(controller.loads, 0);
      expect(provider.isConnecting, false);
      expect(hits['SetLocale'], isNull);
    });
  }

  test('default budget: silent CheckToken ends within 25 seconds, not 10 x 15 seconds', () async {
    provider.authConnectDuration = 5000;
    provider.authConnectRetryDelay = 500;
    silent.add('CheckToken');
    final watch = Stopwatch()..start();
    await expectLater(provider.connect(_Controller()).timeout(const Duration(seconds: 25)), throwsA(isA<NsgApiException>()));
    expect(hits['CheckToken'], 3);
    expect(watch.elapsedMilliseconds, inInclusiveRange(15000, 24000));
    stdout.writeln('auth_connect_default_ms=${watch.elapsedMilliseconds}; attempts=${hits['CheckToken']}');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('custom startup parameters are honored, a new connect gets a fresh budget', () async {
    provider.authConnectMaxAttempts = 2;
    silent.add('CheckToken');
    for (var pass = 0; pass < 2; pass++) {
      await expectLater(provider.connect(_Controller()), throwsA(isA<NsgApiException>()));
    }
    expect(hits['CheckToken'], 4);
  });

  test('overlapping connects keep startup scope until both calls finish', () async {
    provider.useNsgAuthorization = false;
    final first = Completer<void>();
    final second = Completer<void>();
    final a = provider.connect(_Controller(load: () => first.future));
    final b = provider.connect(_Controller(load: () => second.future));
    await Future<void>.delayed(Duration.zero);
    first.complete();
    await a;
    final whileSecondIsPending = provider.isConnecting;
    second.complete();
    await b;
    expect(whileSecondIsPending, true);
    expect(provider.isConnecting, false);
  });

  for (final status in [400, 403, 409, 500, 503]) {
    test('HTTP $status is a server response, never retried', () async {
      statuses['CheckToken'] = status;
      await expectLater(provider.connect(_Controller()), throwsA(isA<NsgApiException>().having((e) => e.error.code, 'HTTP', status)));
      expect(hits['CheckToken'], 1);
      expect(hits['AnonymousLogin'], isNull);
    });
  }

  test('401 is not retried: existing anonymous-login fallback is preserved', () async {
    statuses['CheckToken'] = 401;
    final controller = _Controller();
    await provider.connect(controller);
    expect(hits['CheckToken'], 1);
    expect(hits['AnonymousLogin'], 1);
    expect(controller.loads, 1);
    expect(provider.token, 'test-token');
  });

  test('SetLocale retains one best-effort attempt, now with the startup deadline', () async {
    silent.add('SetLocale');
    final controller = _Controller();
    final watch = Stopwatch()..start();
    await provider.connect(controller);
    expect(hits['SetLocale'], 1);
    expect(controller.loads, 1);
    expect(watch.elapsedMilliseconds, lessThan(1200));
  });

  test('GetServerTime on the connect path is capped, data requests are not', () async {
    silent.add('GetServerTime');
    final controller = _Controller(load: () async {
      await provider.baseRequest(function: 'GetServerTime', url: '$url/Api/GetServerTime', autoRepeate: true, autoRepeateCount: 10);
    });
    await expectLater(provider.connect(controller), throwsA(isA<NsgApiException>()));
    expect(hits['GetServerTime'], 3);
    expect(controller.loads, 1);

    statuses['Data'] = 503;
    await provider.connect(_Controller(load: () async {
      await expectLater(provider.baseRequest(function: 'Data', url: '$url/Api/Data', autoRepeate: true, autoRepeateCount: 4), throwsA(isA<NsgApiException>()));
    }));
    expect(hits['Data'], 4, reason: 'ordinary request retry semantics are unchanged');
  });

  test('outside connect, SetLocale keeps the old independent timeout', () async {
    provider.authRequestDuration = 250;
    silent.add('SetLocale');
    final watch = Stopwatch()..start();
    await provider.setLocale(languageCode: 'ru');
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(200));
    expect(hits['SetLocale'], 1);
  });
}
