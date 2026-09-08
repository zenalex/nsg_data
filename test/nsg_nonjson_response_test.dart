// Ответ не той формы должен называть себя, а не падать голым кастом
// (NSG-SOFT/futbolista-tasks#1922, GT-4675).
//
// 05.09.2026 у пользователя на iPhone на каждый запрос к data1.futbolista.me
// приезжала HTML-страница: телефон только что подключился к Wi-Fi, и соединение
// перехватывалось. В `_requestItems` тело, не оказавшееся ни Map, ни List,
// заворачивалось в список из одного элемента — `response = <dynamic>[response]`,
// — после чего `_fromJsonList` приводил элемент к `Map<String, dynamic>`.
// Успешно разобраться такой список не мог никогда: скаляр не Map.
//
// Цена была не в самом падении, а в том, ЧТО падало:
//
//  * `TypeError` — это `Error`, а не `Exception`. Его не ловит `on Exception` в
//    `NsgBaseController._requestItems`, поэтому экран не получал статус ошибки
//    и оставался в бесконечной загрузке;
//  * в сообщении не было ни адреса запроса, ни типа данных, ни намёка на то,
//    что приехало. Разбор GT-4675 встал именно на этом: по стеку не удавалось
//    назвать даже эндпойнт, и задача неделю висела с вопросом к постановщику.
//
// Здесь закреплено и то, и другое: ошибка ловится как Exception и называет
// запрос, тип и начало тела.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Страница-перехватчик ровно той формы, что пришла в инциденте: XHTML 1.0
/// Transitional. Наш сервер так не отвечает — на 404/405 он отдаёт JSON.
const _captivePortalHtml = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" '
    '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n'
    '<html><head><title>Wi-Fi</title></head><body>Авторизуйтесь в сети</body></html>';

class NonJsonItem extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';

  @override
  String get typeName => 'NonJsonItem';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
  }

  @override
  String get apiRequestItems => '/Api/NonJsonItem';

  @override
  NsgDataItem getNewObject() => NonJsonItem();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

/// Провайдер, который отдаёт заранее заданное тело и считает обращения.
class _BodyProvider extends NsgDataProvider {
  _BodyProvider()
      : super(
          applicationName: 'test',
          firebaseToken: '',
          applicationVersion: '1.0',
          availableServers: NsgServerParams(<String, String>{}, ''),
          newTableLogic: true,
        );

  /// Что «сервер» вернёт на следующий запрос.
  dynamic body;

  int calls = 0;

  @override
  Future<dynamic> baseRequestList({
    final String? function,
    final Map<String, dynamic>? params,
    final dynamic postData,
    final Map<String, String?>? headers,
    final String? url,
    final String method = 'GET',
    final NsgCancelToken? cancelToken,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    calls++;
    return body;
  }
}

void main() {
  late _BodyProvider provider;

  setUpAll(() {
    provider = _BodyProvider();
    if (!NsgDataClient.client.isRegistered(NonJsonItem)) {
      NsgDataClient.client.registerDataItem(NonJsonItem(), remoteProvider: provider);
    }
  });

  setUp(() {
    provider.calls = 0;
    provider.body = null;
  });

  Future<Object?> request({bool autoRepeate = false}) async {
    try {
      await NsgDataRequest<NonJsonItem>(dataItemType: NonJsonItem).requestItems(
        loadReference: const <String>[],
        autoRepeate: autoRepeate,
      );
      return null;
    } catch (e) {
      return e;
    }
  }

  group('ответ не той формы', () {
    test('HTML вместо JSON — Exception с адресом запроса и началом тела, а не TypeError', () async {
      provider.body = _captivePortalHtml;

      final error = await request();

      // Главное свойство: это Exception. `NsgBaseController._requestItems`
      // ловит `on Exception` — только так экран получает статус ошибки вместо
      // вечной загрузки. TypeError туда не попадал.
      expect(error, isA<Exception>(), reason: 'на Error экран остаётся в загрузке — ради этого правка и делалась');
      expect(error, isA<NsgApiException>());

      final text = error.toString();
      expect(text, contains('/Api/NonJsonItem'), reason: 'без адреса запроса событие в телеметрии неадресуемо');
      expect(text, contains('NonJsonItem'), reason: 'какой тип грузили — второй недостающий факт');
      expect(text, contains('DOCTYPE html'), reason: 'по началу тела видно, что это подмена ответа, а не наш сервер');
    });

    test('в тексте ошибки только начало тела, а не вся страница', () async {
      // Тело может быть страницей на десятки килобайт. Целиком оно и бесполезно,
      // и утекает в телеметрию.
      provider.body = '${_captivePortalHtml}x' * 50;

      final error = await request();

      expect(error.toString().length, lessThan(600));
      expect(error.toString(), contains('...'));
    });

    test('массив строк вместо массива объектов — ошибка называет номер элемента', () async {
      // Вторая форма того же дефекта: список пришёл, но элементы в нём не
      // объекты. Каст падал ровно тем же безымянным TypeError.
      provider.body = <dynamic>[
        {'id': '1', 'name': 'ок'},
        'сообщение об ошибке',
      ];

      final error = await request();

      expect(error, isA<NsgApiException>());
      expect(error.toString(), contains('[1]'));
      expect(error.toString(), contains('сообщение об ошибке'));
    });

    test('ответ неожиданной формы не ретраится', () async {
      // Тело уже получено целиком — повтор его не исправит. Десять попыток с
      // паузой до 15 секунд держали бы экран в загрузке минутами; до правки
      // TypeError не ретраился вовсе, и быстрый отказ надо было сохранить.
      provider.body = _captivePortalHtml;

      final error = await request(autoRepeate: true);

      expect(error, isA<NsgApiException>());
      expect(provider.calls, 1, reason: 'повторять запрос с заведомо негодным телом бессмысленно');
    });

    test('нормальный ответ по-прежнему разбирается', () async {
      provider.body = <dynamic>[
        {'id': 'ok-1', 'name': 'Спартак'},
      ];

      final items = await NsgDataRequest<NonJsonItem>(dataItemType: NonJsonItem).requestItems(
        loadReference: const <String>[],
        autoRepeate: false,
      );

      expect(items, hasLength(1));
      expect(items.single.getFieldValue(NonJsonItem.nameName), 'Спартак');
    });

    test('пустой ответ — пустой список, а не ошибка', () async {
      // `response == '' || response == null` — законное «ничего не найдено».
      provider.body = '';

      final items = await NsgDataRequest<NonJsonItem>(dataItemType: NonJsonItem).requestItems(
        loadReference: const <String>[],
        autoRepeate: false,
      );

      expect(items, isEmpty);
    });
  });
}
