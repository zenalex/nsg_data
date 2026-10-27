import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class _CountRow extends NsgDataItem {
  @override
  String get typeName => 'ResultsCountRow';
  @override
  String get apiRequestItems => '/Api/ResultsCountRow';
  @override
  void initialize() {
    addField(NsgDataStringField('id'), primaryKey: true);
  }

  @override
  NsgDataItem getNewObject() => _CountRow();
  @override
  String get id => getFieldValue('id').toString();
  @override
  set id(String value) => setFieldValue('id', value);
}

class _CountProvider extends NsgDataProvider {
  _CountProvider(this.count)
    : super(
        applicationName: 'count-test',
        applicationVersion: '0',
        firebaseToken: '',
        availableServers: NsgServerParams({}, ''),
      );
  Object? count;
  int calls = 0;
  @override
  Future<dynamic> baseRequestList({
    String? function,
    Map<String, dynamic>? params,
    dynamic postData,
    Map<String, String?>? headers,
    String? url,
    String method = 'GET',
    NsgCancelToken? cancelToken,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    calls++;
    return {
      'resultsCount': count,
      'results': [
        {'id': '10000000-0000-4000-8000-000000000001'},
        {'id': '10000000-0000-4000-8000-000000000002'},
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = <({String name, Object? count, int? expected})>[
    (name: 'string', count: '42', expected: 42),
    (name: 'zero string', count: '0', expected: 0),
    (name: 'integer', count: 42, expected: 42),
    (name: 'zero integer', count: 0, expected: 0),
    (name: 'wrapped string', count: ['42'], expected: 42),
    (name: 'wrapped integer', count: [42], expected: 42),
    (name: 'empty list remains unknown', count: [], expected: null),
    (
      name: 'multiple counts are not list length',
      count: [42, 43],
      expected: null,
    ),
    (name: 'invalid string remains unknown', count: 'unknown', expected: null),
    (name: 'null remains unknown', count: null, expected: null),
    (name: 'map remains unknown', count: {'count': 42}, expected: null),
    (
      name: 'nested list remains unknown',
      count: [
        ['42'],
      ],
      expected: null,
    ),
  ];
  test(
    'a reused request clears the previous count when metadata is ambiguous',
    () async {
      final provider = _CountProvider('42');
      NsgDataClient.client.registerDataItem(
        _CountRow(),
        remoteProvider: provider,
      );
      final request = NsgDataRequest<_CountRow>(dataItemType: _CountRow);
      await request.requestItems(autoRepeate: false, loadReference: []);
      expect(request.totalCount, 42);
      provider.count = [42, 43];
      final rows = await request.requestItems(
        autoRepeate: false,
        loadReference: [],
      );
      expect(rows, hasLength(2));
      expect(request.totalCount, isNull);
      expect(provider.calls, 2);
    },
  );

  for (final c in cases) {
    test('request preserves rows and parses resultsCount: ${c.name}', () async {
      final provider = _CountProvider(c.count);
      NsgDataClient.client.registerDataItem(
        _CountRow(),
        remoteProvider: provider,
      );
      final request = NsgDataRequest<_CountRow>(dataItemType: _CountRow);
      final rows = await request.requestItems(
        autoRepeate: false,
        loadReference: [],
      );
      expect(rows.map((r) => r.id), [
        '10000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000002',
      ]);
      expect(request.totalCount, c.expected);
      expect(provider.calls, 1);
    });
  }
}
