// Пакетное сохранение обязано класть созданный объект в мастер-список (#1703).
//
// `postItems` обновлял dataItemList только для элементов, которые в нём УЖЕ
// были. Объект, созданный приложением, уезжал на сервер и в `items` не попадал —
// экран, который строит вид из `items`, сохранённого объекта не видел.
// У организатора это выглядело как «разложил матчи по турам, сохранил,
// переключил группу, вернулся — все туры пустые», при том что на сервере матчи
// есть.
//
// Тест сторожит обе стороны: без добавления сохранённое пропадает, с
// добавлением «вслепую» — задваивается. И отдельно — что в список кладётся
// экземпляр ВЫЗЫВАЮЩЕГО, иначе один объект окажется на экране дважды.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/controllers/nsg_posted_items_merge.dart';
import 'package:nsg_data/nsg_data.dart';

class Row extends NsgDataItem {
  static const nameId = 'id';
  static const nameText = 'text';

  @override
  String get typeName => 'Row';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(NsgDataItem.nameOwnerId), primaryKey: false);
    addField(NsgDataStringField(nameText), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => Row();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);

  @override
  String get ownerId => getFieldValue(NsgDataItem.nameOwnerId).toString();
  @override
  set ownerId(String value) => setFieldValue(NsgDataItem.nameOwnerId, value);

  String get text => getFieldValue(nameText).toString();
  set text(String value) => setFieldValue(nameText, value);
}

Row row(String id, String text) => Row()
  ..id = id
  ..text = text;

void main() {
  setUpAll(() {
    NsgDataClient.client.registerDataItem(Row());
  });

  group('applyPostedItems', () {
    test('созданный объект попадает в мастер-список — это и есть #1703', () {
      final master = <NsgDataItem>[row('a', 'из базы')];
      final posted = <NsgDataItem>[row('b', 'создан приложением')];
      final fromServer = <NsgDataItem>[row('b', 'создан приложением')];

      final added = applyPostedItems(postedItems: posted, serverItems: fromServer, dataItemList: master);

      expect(added.length, 1);
      expect(master.map((e) => e.id), ['a', 'b'], reason: 'без этого экран, строящий вид из items, объекта не увидит');
    });

    test('известный объект обновляется на месте, а не добавляется вторым', () {
      // «Сохранить» шлёт новые и отредактированные вперемешку; добавить
      // известного — значит задвоить строку в каждом списке по контроллеру.
      final known = row('a', 'старое');
      final master = <NsgDataItem>[known];
      final posted = <NsgDataItem>[known];
      final fromServer = <NsgDataItem>[row('a', 'новое')];

      final added = applyPostedItems(postedItems: posted, serverItems: fromServer, dataItemList: master);

      expect(added, isEmpty);
      expect(master.length, 1);
      expect((master.single as Row).text, 'новое');
      expect(identical(master.single, known), isTrue, reason: 'экземпляр в списке остаётся прежним');
    });

    test('новые и известные в одной пачке разбираются каждый по-своему', () {
      final known = row('a', 'старое');
      final master = <NsgDataItem>[known];
      final fresh = row('b', 'новый');
      final posted = <NsgDataItem>[known, fresh];
      final fromServer = <NsgDataItem>[row('a', 'новое'), row('b', 'новый')];

      final added = applyPostedItems(postedItems: posted, serverItems: fromServer, dataItemList: master);

      expect(added.map((e) => e.id), ['b']);
      expect(master.map((e) => e.id), ['a', 'b']);
      expect((master.first as Row).text, 'новое');
    });

    test('в список кладётся экземпляр ВЫЗЫВАЮЩЕГО, а не объект сервера', () {
      // Иначе у вызывающего на руках остаётся прежний экземпляр, и один
      // объект оказывается на экране дважды — «свой» и «из контроллера».
      final master = <NsgDataItem>[];
      final fresh = row('b', 'локальный');
      final posted = <NsgDataItem>[fresh];
      final fromServer = <NsgDataItem>[row('b', 'серверный')];

      applyPostedItems(postedItems: posted, serverItems: fromServer, dataItemList: master);

      expect(identical(master.single, fresh), isTrue);
      expect((master.single as Row).text, 'серверный', reason: 'значения всё равно приезжают с сервера');
    });

    test('сохранённое помечается загруженным', () {
      final master = <NsgDataItem>[];
      final fresh = row('b', 'локальный')..state = NsgDataItemState.create;
      applyPostedItems(postedItems: [fresh], serverItems: [row('b', 'серверный')], dataItemList: master);

      expect(fresh.state, NsgDataItemState.fill);
      expect(master.single.state, NsgDataItemState.fill);
    });

    test('повторное применение того же ответа ничего не добавляет', () {
      // Экран может сохранить дважды подряд; второй проход обязан быть пустым.
      final master = <NsgDataItem>[];
      final fresh = row('b', 'x');

      applyPostedItems(postedItems: [fresh], serverItems: [row('b', 'x')], dataItemList: master);
      final second = applyPostedItems(postedItems: [fresh], serverItems: [row('b', 'x')], dataItemList: master);

      expect(second, isEmpty);
      expect(master.length, 1);
    });

    test('сервер вернул объект, которого не отправляли — берём серверный', () {
      // Такое бывает, когда пост порождает связанные записи. Терять их хуже,
      // чем положить чужой экземпляр: своего у вызывающего всё равно нет.
      final master = <NsgDataItem>[];
      final added = applyPostedItems(postedItems: [], serverItems: [row('z', 'побочный')], dataItemList: master);

      expect(added.map((e) => e.id), ['z']);
      expect(master.single.state, NsgDataItemState.fill);
    });

    test('сервер не вернул ничего — список не трогаем', () {
      final master = <NsgDataItem>[row('a', 'из базы')];
      final added = applyPostedItems(postedItems: [row('a', 'из базы')], serverItems: [], dataItemList: master);

      expect(added, isEmpty);
      expect(master.length, 1);
    });
  });
}
