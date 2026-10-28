import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

class _Row extends NsgDataItem {
  @override
  String get typeName => 'CancelRow3835';
  @override
  String get apiRequestItems => '/Api/CancelRow3835';
  @override
  void initialize() {
    addField(NsgDataStringField('id'), primaryKey: true);
    addField(NsgDataStringField('name'));
  }

  @override
  String get id => getFieldValue('id').toString();
  @override
  NsgDataItem getNewObject() => _Row();
}

class _Provider extends NsgDataProvider {
  _Provider()
    : super(
        applicationName: 'cancel-test',
        applicationVersion: '0',
        firebaseToken: '',
        availableServers: NsgServerParams({}, ''),
      );
  NsgCancelToken? seen;
  Completer<dynamic>? pending;
  final started = Completer<void>();
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
    seen = cancelToken;
    if (!started.isCompleted) started.complete();
    return pending == null ? {'results': []} : pending!.future;
  }
}

void main() {
  for (final typed in [false, true]) {
    test(
      '${typed ? 'data' : 'simple'} request forwards caller token',
      () async {
        final provider = _Provider();
        final token = NsgCancelToken();
        NsgDataClient.client.registerDataItem(_Row(), remoteProvider: provider);
        if (typed) {
          await NsgDataRequest<_Row>().requestItems(
            loadReference: [],
            autoRepeate: false,
            cancelToken: token,
          );
        } else {
          await NsgSimpleRequest<String>().requestItems(
            provider: provider,
            function: '/cancel-fixture',
            cancelToken: token,
          );
        }
        expect(provider.seen, same(token));
      },
    );
  }
  test(
    'scope inherits across awaits and null scope isolates an atomic operation',
    () async {
      final token = NsgCancelToken();
      await NsgCancelToken.runScoped(token, () async {
        await Future<void>.delayed(Duration.zero);
        expect(NsgCancelToken.current, same(token));
        await NsgCancelToken.runScoped(null, () async {
          await Future<void>.delayed(Duration.zero);
          expect(NsgCancelToken.current, isNull);
        });
        expect(NsgCancelToken.current, same(token));
      });
      expect(NsgCancelToken.current, isNull);
    },
  );
  test(
    'cancelled late response never changes cached item and never retries',
    () async {
      final provider = _Provider()..pending = Completer<dynamic>();
      NsgDataClient.client.registerDataItem(_Row(), remoteProvider: provider);
      final cached = _Row()
        ..id = 'cancel-cache-3835'
        ..setFieldValue('name', 'draft');
      NsgDataClient.client.addItemsToCache(items: [cached]);
      final token = NsgCancelToken();
      final request = NsgDataRequest<_Row>();
      final result = NsgCancelToken.runScoped(
        token,
        () => request.requestItems(
          loadReference: [],
          autoRepeate: true,
          autoRepeateCount: 3,
        ),
      );
      final check = expectLater(result, throwsA(isA<NsgOperationCancelled>()));
      await provider.started.future;
      token.calcel();
      provider.pending!.complete({
        'results': [
          {'id': cached.id, 'name': 'server-late'},
        ],
      });
      await check;
      expect(
        NsgDataClient.client
            .getItemsFromCacheTyped<_Row>(cached.id)!
            .getFieldValue('name'),
        'draft',
      );
      expect(request.items, isEmpty);
    },
  );
  test('a reused request does not cancel caller-owned token', () async {
    final provider = _Provider();
    final request = NsgSimpleRequest<String>();
    final first = NsgCancelToken();
    await request.requestItems(
      provider: provider,
      function: '/fixture',
      cancelToken: first,
    );
    await request.requestItems(
      provider: provider,
      function: '/fixture',
      cancelToken: NsgCancelToken(),
    );
    expect(first.isCancelled, isFalse);
  });
  for (final useList in [false, true]) {
    test(
      'real Dio ${useList ? 'list' : 'base'} request stops on scoped cancellation without retry',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final started = Completer<void>();
        var hits = 0;
        server.listen((request) {
          hits++;
          if (!started.isCompleted) started.complete();
        });
        final url = 'http://127.0.0.1:${server.port}/cancel';
        final provider = NsgDataProvider(
          applicationName: 'loopback',
          applicationVersion: '0',
          firebaseToken: '',
          availableServers: NsgServerParams({}, ''),
        );
        final token = NsgCancelToken();
        final request = NsgCancelToken.runScoped(
          token,
          () => useList
              ? provider.baseRequestList(url: url)
              : provider.baseRequest(
                  url: url,
                  autoRepeate: true,
                  autoRepeateCount: 3,
                ),
        );
        final check = expectLater(
          request,
          throwsA(isA<NsgOperationCancelled>()),
        );
        await started.future.timeout(const Duration(seconds: 3));
        token.calcel();
        await check.timeout(const Duration(seconds: 2));
        expect(hits, 1);
      },
    );
  }
}
