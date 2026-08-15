// Контейнер зависимостей v2 (NsgDI).
//
// Зачем: NsgDI владеет жизненным циклом всего, что в него положили — bind
// обязан вызвать init(), unbind и reset обязаны вызвать dispose(). Если
// dispose не позовётся, за объектом останутся живые подписки на стримы и
// таймеры; на экране это выглядит как «данные приходят дважды» или как рост
// памяти, и к самому DI претензий не возникает.
//
// Отдельно проверяется квалификатор: два экземпляра одного типа (например, два
// контроллера списка на разных вкладках) различаются только им, и промах по
// квалификатору means чужой объект получит dispose.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/v2/base/nsg_di.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';

class Probe implements NsgLifecycle {
  Probe(this.label);

  final String label;
  int initCalls = 0;
  int disposeCalls = 0;

  @override
  void init() => initCalls++;

  @override
  void dispose() => disposeCalls++;
}

class OtherProbe implements NsgLifecycle {
  int disposeCalls = 0;

  @override
  void init() {}

  @override
  void dispose() => disposeCalls++;
}

void main() {
  test('bind вызывает init и делает объект находимым', () async {
    final di = NsgDI();
    final probe = Probe('main');

    await di.bind<Probe>(probe);

    expect(probe.initCalls, 1, reason: 'без init объект отдадут неинициализированным');
    expect(di.find<Probe>(), same(probe));
    expect(di.findOrNull<Probe>(), same(probe));
  });

  test('unbind вызывает dispose и убирает привязку', () async {
    final di = NsgDI();
    final probe = Probe('main');
    await di.bind<Probe>(probe);

    await di.unbind<Probe>();

    expect(probe.disposeCalls, 1);
    expect(di.findOrNull<Probe>(), isNull);
  });

  test('reset гасит всё и очищает контейнер', () async {
    final di = NsgDI();
    final first = Probe('first');
    final second = OtherProbe();
    await di.bind<Probe>(first);
    await di.bind<OtherProbe>(second);

    await di.reset();

    expect(first.disposeCalls, 1);
    expect(second.disposeCalls, 1);
    expect(di.findOrNull<Probe>(), isNull);
    expect(di.findOrNull<OtherProbe>(), isNull);
  });

  group('квалификатор', () {
    test('два экземпляра одного типа живут рядом', () async {
      final di = NsgDI();
      final left = Probe('left');
      final right = Probe('right');

      await di.bind<Probe>(left, 'left');
      await di.bind<Probe>(right, 'right');

      expect(di.find<Probe>('left'), same(left));
      expect(di.find<Probe>('right'), same(right));
    });

    test('unbind гасит СВОЙ экземпляр, а не соседний', () async {
      // Регрессия: unbind искал объект через find<T>() БЕЗ квалификатора, а
      // удалял по ключу С квалификатором. То есть dispose доставался чужому
      // экземпляру (или падал с TypeError, если безымянной привязки нет), а
      // свой оставался жить с закрытым соседом.
      final di = NsgDI();
      final left = Probe('left');
      final right = Probe('right');
      await di.bind<Probe>(left, 'left');
      await di.bind<Probe>(right, 'right');

      await di.unbind<Probe>('left');

      expect(left.disposeCalls, 1, reason: 'гасить должны именно тот, что просили');
      expect(right.disposeCalls, 0, reason: 'соседний экземпляр трогать нельзя');
      expect(di.findOrNull<Probe>('left'), isNull);
      expect(di.findOrNull<Probe>('right'), same(right));
    });

    test('unbind по квалификатору работает и без безымянной привязки', () async {
      // Ровно тот случай, когда старый код падал: find<T>() возвращал null,
      // а приведение null as T на непустом типе — TypeError.
      final di = NsgDI();
      final only = Probe('only');
      await di.bind<Probe>(only, 'only');

      await expectLater(di.unbind<Probe>('only'), completes);
      expect(only.disposeCalls, 1);
    });
  });
}
