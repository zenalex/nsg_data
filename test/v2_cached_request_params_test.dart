// Ключ кэша запросов в v2 (NsgCachedRequestParams).
//
// Зачем: этот ключ — единственное, что связывает выполненный fetchItems с
// последующим selectCount. Источники данных v2 (NsgRemoteDataSource,
// NsgLocalDataSource) кладут запрос в _cachedRequests под этим ключом, а
// selectCount по нему достаёт totalCount вместо похода на сервер.
//
// Поэтому набор полей, которые ключ ИГНОРИРУЕТ, — это осознанное решение, а не
// случайность: totalCount не зависит от того, сколько строк попросили (top,
// count), в каком порядке (sorting), какие колонки и ссылки дочитывали
// (neededFields, referenceList) и под каким идентификатором шёл запрос
// (requestId, transactionId). А вот условия отбора (compare) на число строк
// влияют напрямую — и обязаны ключ менять.
//
// Тест фиксирует ровно это. Без него любая «оптимизация» ключа выглядит
// безобидной: перепутать эти два списка местами — значит либо отдать чужое
// число (если compare перестанет учитываться), либо навсегда потерять попадания
// в кэш (если начнёт учитываться sorting).

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/data_source/nsg_cached_request_params.dart';

String keyOf(NsgDataRequestParams params) => NsgCachedRequestParams(params: params).toString();

NsgDataRequestParams paramsWithFilter(String value) {
  final params = NsgDataRequestParams();
  params.compare.add(name: 'name', value: value, comparisonOperator: NsgComparisonOperator.equal);
  return params;
}

void main() {
  group('ключ НЕ зависит от полей, не влияющих на количество строк', () {
    test('top и count', () {
      final a = paramsWithFilter('team')..top = 10;
      final b = paramsWithFilter('team')..top = 500;
      final c = paramsWithFilter('team')..count = 50;

      expect(keyOf(a), keyOf(b), reason: 'сколько строк попросили — не меняет их общего числа');
      expect(keyOf(a), keyOf(c));
    });

    test('порядок сортировки', () {
      final a = paramsWithFilter('team')..sorting = 'name';
      final b = paramsWithFilter('team')..sorting = 'date desc';

      expect(keyOf(a), keyOf(b), reason: 'порядок не меняет состав выборки');
    });

    test('дочитывание ссылок и набор колонок', () {
      final a = paramsWithFilter('team')
        ..referenceList = ['tournamentId']
        ..neededFields = ['id', 'name'];
      final b = paramsWithFilter('team')
        ..referenceList = null
        ..neededFields = null;

      expect(keyOf(a), keyOf(b), reason: 'ширина строки не влияет на их количество');
    });

    test('requestId и transactionId', () {
      final a = paramsWithFilter('team')
        ..requestId = 'req-1'
        ..transactionId = 'tran-1';
      final b = paramsWithFilter('team')
        ..requestId = 'req-2'
        ..transactionId = 'tran-2';

      expect(keyOf(a), keyOf(b), reason: 'иначе кэш не попадал бы НИКОГДА — идентификаторы уникальны');
    });
  });

  group('ключ зависит от условий отбора', () {
    test('разные значения фильтра — разные ключи', () {
      expect(keyOf(paramsWithFilter('Спартак')), isNot(keyOf(paramsWithFilter('Динамо'))),
          reason: 'совпади они — selectCount отдал бы число чужой выборки');
    });

    test('фильтр против его отсутствия', () {
      expect(keyOf(paramsWithFilter('Спартак')), isNot(keyOf(NsgDataRequestParams())));
    });

    test('лишнее условие меняет ключ', () {
      final narrow = paramsWithFilter('Спартак')
        ..compare.add(name: 'year', value: '2026', comparisonOperator: NsgComparisonOperator.equal);

      expect(keyOf(narrow), isNot(keyOf(paramsWithFilter('Спартак'))));
    });
  });

  test('ключ устойчив: одни и те же параметры дают одну строку', () {
    final params = paramsWithFilter('team');

    expect(keyOf(params), keyOf(params));
    expect(keyOf(paramsWithFilter('team')), keyOf(paramsWithFilter('team')),
        reason: 'нестабильный ключ = вечный промах кэша, и заметить это нечем');
  });

  test('вычисление ключа не портит исходные параметры', () {
    // toString() зануляет поля на клоне. Если клонирование когда-нибудь
    // потеряется, запрос уедет на сервер без top/sorting — и это будет тихо.
    final params = paramsWithFilter('team')
      ..top = 25
      ..sorting = 'name'
      ..referenceList = ['tournamentId'];

    keyOf(params);

    expect(params.top, 25);
    expect(params.sorting, 'name');
    expect(params.referenceList, ['tournamentId']);
  });
}
