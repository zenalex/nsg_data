// 401 из сетевого слоя доходит до обработчика истёкшей сессии
// (NSG-SOFT/futbolista-tasks#176, GT-4619).
//
// `NsgApiException.showExceptionDefault` пакет звал только из `itemPagePost`.
// Загрузка получала 401 из `baseRequestList` и бросала его вверх; если
// вызывающий не ловил, исключение становилось необработанным. Приложение ловило
// такие ошибки через `PlatformDispatcher.onError`, но веб-движок Flutter этот
// колбэк не вызывает никогда — на вебе 401 уходил в `window.onerror`, и
// обработчик сессии не срабатывал. В расшифрованном стеке GT-4619 так и есть:
// `baseRequestList` → асинхронная машинерия → обработчик зоны.
//
// Здесь закреплено:
//  * 401 доходит до хука `NsgApiException.onSessionExpired`, а вызывающий
//    получает то же исключение, что и раньше;
//  * без хука пакет ведёт себя как до правки — `showExceptionDefault` (диалог
//    nsg_controls) на загрузке не зовётся;
//  * пачка 401 одной сессии — один вызов хука;
//  * запоздавший ответ прежней сессии, анонимная сессия и пустой токен в хук
//    не идут;
//  * `itemPagePost` не показывает уже обработанный хуком 401 второй раз.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/src/unauthorized_dispatch.dart';

class SessionItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'SessionItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  String get apiRequestItems => '/Api/SessionItem';

  @override
  NsgDataItem getNewObject() => SessionItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

void main() {
  late HttpServer server;
  late NsgDataProvider provider;

  /// Что «сервер» ответит на следующий запрос.
  var status = 401;
  var hits = 0;

  /// Что дошло до хука истёкшей сессии.
  final routed = <NsgApiException>[];

  /// Что дошло до обработчика по умолчанию (в приложениях — диалог nsg_controls).
  final shown = <NsgApiException>[];

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      hits++;
      await request.drain<void>();
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{}');
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
    if (!NsgDataClient.client.isRegistered(SessionItem)) {
      NsgDataClient.client.registerDataItem(SessionItem(), remoteProvider: provider);
    }
  });

  tearDownAll(() async => server.close(force: true));

  setUp(() {
    status = 401;
    hits = 0;
    routed.clear();
    shown.clear();
    provider.token = 'user-token';
    provider.isAnonymous = false;
    NsgUnauthorizedDispatch.resetForTesting();
    NsgApiException.onSessionExpired = routed.add;
    NsgApiException.showExceptionDefault = shown.add;
  });

  tearDown(() {
    NsgApiException.onSessionExpired = null;
    NsgApiException.showExceptionDefault = null;
    NsgUnauthorizedDispatch.resetForTesting();
  });

  /// Запрос мимо любого контроллера — ровно как загрузка, упавшая в GT-4619.
  Future<Object?> load({Map<String, String?>? headers}) async {
    try {
      await provider.baseRequestList(
        function: 'SessionItem',
        url: '${provider.serverUri}/Api/SessionItem',
        headers: headers ?? provider.getAuthorizationHeader(),
        method: 'POST',
      );
      return null;
    } catch (e) {
      return e;
    }
  }

  group('401 из baseRequestList', () {
    test('доходит до хука, а вызывающий получает то же исключение', () async {
      final error = await load();

      expect(error, isA<NsgApiException>(), reason: 'контракт вызывающих не меняется: 401 по-прежнему бросается');
      expect((error as NsgApiException).error.code, 401);
      expect(routed, hasLength(1), reason: 'до правки обработчик на этом пути не вызывался вовсе');
      expect(identical(routed.single, error), isTrue);
      expect(shown, isEmpty, reason: 'обработчик по умолчанию сетевой слой не зовёт никогда');
    });

    test('хук не задан — на загрузке не вызывается ничего, как до правки', () async {
      // showExceptionDefault в nsg_controls — диалог «ERROR 401». Приложения,
      // которые хук не ставили, не должны начать видеть его при загрузке.
      NsgApiException.onSessionExpired = null;

      final error = await load();

      expect(error, isA<NsgApiException>());
      expect((error as NsgApiException).error.code, 401);
      expect(shown, isEmpty);
      expect(NsgUnauthorizedDispatch.isRouted(error), isFalse);
    });

    test('анонимная сессия в хук не идёт', () async {
      provider.token = 'anon-token';
      provider.isAnonymous = true;

      final error = await load();

      expect(error, isA<NsgApiException>());
      expect(routed, isEmpty, reason: 'истекать нечему — это отказ анонимному доступу');
      expect(NsgUnauthorizedDispatch.isRouted(error as NsgApiException), isFalse);
    });

    test('хук перевёл провайдер на анонимный токен — следующий 401 в хук не идёт', () async {
      // Ровно так выходит из сессии приложение: сбрасывает токен и получает
      // анонимный. 401 уже под ним — не «вторая истёкшая сессия», а повод для
      // петли выходов.
      NsgApiException.onSessionExpired = (ex) {
        routed.add(ex);
        provider.token = 'anon-token';
        provider.isAnonymous = true;
      };

      await load();
      await load();

      expect(routed, hasLength(1));
    });

    test('пустой токен в хук не идёт', () async {
      provider.token = '';

      final error = await load();

      expect(error, isA<NsgApiException>());
      expect(routed, isEmpty);
    });

    test('загрузка через NsgDataRequest: один вызов хука и без повторов запроса', () async {
      Object? error;
      try {
        await NsgDataRequest<SessionItem>(dataItemType: SessionItem).requestItems(
          loadReference: const <String>[],
          autoRepeate: true,
        );
      } catch (e) {
        error = e;
      }

      expect(error, isA<NsgApiException>());
      expect(routed, hasLength(1));
      expect(hits, 1, reason: '401 не ретраится — это поведение сохраняем');
    });

    test('пачка параллельных 401 одной сессии — один вызов хука', () async {
      final errors = await Future.wait([load(), load(), load()]);

      expect(errors, everyElement(isA<NsgApiException>()), reason: 'каждый вызывающий по-прежнему узнаёт об отказе');
      expect(routed, hasLength(1));
    });

    test('после окна пачки 401 той же сессии снова доходит до хука', () async {
      var now = DateTime(2026, 9, 14, 12);
      NsgUnauthorizedDispatch.clock = () => now;

      await load();
      now = now.add(const Duration(seconds: 5));
      await load();
      expect(routed, hasLength(1), reason: 'внутри окна — та же пачка');

      now = now.add(NsgUnauthorizedDispatch.burstWindow);
      await load();
      expect(routed, hasLength(2), reason: 'гасим повторы, а не саму сессию навсегда');
    });

    test('запоздавший ответ прежней сессии текущую не трогает', () async {
      // Запрос ушёл со старым токеном, а за время ответа сессия сменилась —
      // обработчик первого 401 уже вышел и завёл новую. Отдать этот ответ в
      // хук значило бы выйти из сессии, которая жива.
      provider.token = 'new-token';

      final error = await load(headers: {'Authorization': 'old-token'});

      expect(error, isA<NsgApiException>());
      expect((error as NsgApiException).error.code, 401);
      expect(routed, isEmpty);
      expect(NsgUnauthorizedDispatch.isRouted(error), isFalse,
          reason: 'хук этот 401 не видел — верхний слой показывает его как до правки');
    });

    test('новая сессия получает свой вызов и внутри окна прежней', () async {
      await load();
      provider.token = 'relogin-token';
      await load();

      expect(routed, hasLength(2), reason: 'окно гасит повторы одного токена, а не любой 401');
    });

    test('сбой хука не подменяет 401', () async {
      NsgApiException.onSessionExpired = (ex) => throw StateError('обработчик упал');

      final error = await load();

      expect(error, isA<NsgApiException>());
      expect((error as NsgApiException).error.code, 401);
    });

    test('ошибка в async-хуке не становится необработанной', () async {
      // Возвращённый хуком Future иначе остался бы без слушателя, и его ошибка
      // стала бы необработанной.
      NsgApiException.onSessionExpired = (ex) async => throw StateError('обработчик упал позже');

      final error = await load();
      await pumpEventQueue();

      expect(error, isA<NsgApiException>());
    });
  });

  group('другие коды', () {
    for (final code in [403, 500]) {
      test('$code в хук не отдаётся', () async {
        status = code;

        final error = await load();

        expect(error, isA<NsgApiException>());
        expect(routed, isEmpty);
        expect(NsgUnauthorizedDispatch.isRouted(error as NsgApiException), isFalse);
      });
    }
  });

  group('itemPagePost', () {
    Future<Object?> post(NsgBaseController controller) async {
      controller.selectedItem = NsgDataClient.client.getNewObject(SessionItem);
      try {
        await controller.itemPagePost(goBack: false, useValidation: false);
        return null;
      } catch (e) {
        return e;
      }
    }

    test('401 при сохранении — хук один раз, обработчик по умолчанию не зовётся', () async {
      final error = await post(NsgBaseController(dataType: SessionItem));

      expect(error, isA<NsgApiException>());
      expect(routed, hasLength(1));
      expect(shown, isEmpty, reason: 'второй путь дал бы диалог «ERROR 401» поверх выхода из сессии');
    });

    test('хук не задан — 401 при сохранении идёт в обработчик по умолчанию, как до правки', () async {
      NsgApiException.onSessionExpired = null;

      await post(NsgBaseController(dataType: SessionItem));

      expect(shown, hasLength(1));
      expect(shown.single.error.code, 401);
    });

    test('401 анонимной сессии при сохранении идёт в обработчик по умолчанию', () async {
      provider.token = 'anon-token';
      provider.isAnonymous = true;

      await post(NsgBaseController(dataType: SessionItem));

      expect(routed, isEmpty);
      expect(shown, hasLength(1), reason: 'хук этот 401 не видел — гасить его показ нельзя');
    });

    test('свой showException контроллера 401 получает как раньше', () async {
      final own = <NsgApiException>[];
      final controller = NsgBaseController(dataType: SessionItem)..showException = own.add;

      await post(controller);

      expect(own, hasLength(1), reason: 'свой обработчик контроллера гашением не затрагивается');
      expect(routed, hasLength(1));
    });

    test('прочие ошибки сохранения идут в обработчик по умолчанию как раньше', () async {
      status = 500;

      await post(NsgBaseController(dataType: SessionItem));

      expect(routed, isEmpty);
      expect(shown, hasLength(1));
      expect(shown.single.error.code, 500);
    });
  });
}
