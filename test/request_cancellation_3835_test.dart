import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';

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
  final seenTokens = <NsgCancelToken?>[];
  Object? failure;
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
    seenTokens.add(cancelToken);
    if (failure != null) throw failure!;
    if (!started.isCompleted) started.complete();
    return pending == null ? {'results': []} : pending!.future;
  }
}

class _RefRow extends _Row {
  @override
  String get typeName => 'CancelRef3835';
  @override
  NsgDataItem getNewObject() => _RefRow();
}

class _OwnerRow extends _Row {
  @override
  String get typeName => 'CancelOwner3835';
  @override
  void initialize() {
    super.initialize();
    addField(NsgDataReferenceField<_RefRow>('refId'));
  }

  @override
  NsgDataItem getNewObject() => _OwnerRow();
}

class _CancellingController extends NsgDataController<_Row> {
  _CancellingController() : super(requestOnInit: false);
  @override
  Future<List<NsgDataItem>> doRequestItems({
    NsgDataRequestParams? filter,
  }) async => throw const NsgOperationCancelled();
}

class _ControlledController extends NsgDataController<_Row> {
  _ControlledController() : super(requestOnInit: false);
  final requests = <Completer<List<NsgDataItem>>>[];
  @override
  Future<List<NsgDataItem>> doRequestItems({NsgDataRequestParams? filter}) {
    final gate = Completer<List<NsgDataItem>>();
    requests.add(gate);
    return gate.future;
  }
}

class _CancelledCardController extends NsgDataController<_Row> {
  _CancelledCardController() : super(requestOnInit: false);
  @override
  Future<NsgDataItem> doCreateNewItem() async =>
      throw const NsgOperationCancelled();
  @override
  Future<NsgDataItem> refreshItem(
    NsgDataItem item,
    List<String>? referenceList, {
    bool changeStatus = false,
  }) async => throw const NsgOperationCancelled();
}

class _DelayedCancellingController extends _CancellingController {
  @override
  Future requestItems({
    List<NsgUpdateKey>? keys,
    NsgDataRequestParams? filter,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return super.requestItems(keys: keys, filter: filter);
  }
}

class _HydratingRequest extends NsgDataRequest<_Row> {
  final started = Completer<void>();
  final gate = Completer<void>();
  NsgCancelToken? inherited;
  @override
  Future<List> loadDataAndReferences(
    Map response,
    List<String> loadReference,
    String tag, {
    NsgDataRequestParams? filter,
  }) async {
    inherited = NsgCancelToken.current;
    started.complete();
    await gate.future;
    return [];
  }
}

void main() {
  for (final action in ['create', 'refresh', 'copy', 'delayed list']) {
    test(
      'REVIEW $action cancellation restores status and propagates',
      () async {
        NsgDataClient.client.registerDataItem(
          _Row(),
          remoteProvider: _Provider(),
        );
        final controller = action == 'delayed list'
            ? _DelayedCancellingController()
            : _CancelledCardController();
        final previous = GetStatus.success(NsgBaseController.emptyData);
        controller.currentStatus = previous;
        final row = _Row()..id = 'card-3835';
        final Future result;
        switch (action) {
          case 'create':
            result = controller.createAndSetSelectedItem();
          case 'refresh':
            result = controller.setAndRefreshSelectedItem(row, []);
          case 'copy':
            result = controller.copyAndSetItem(
              row,
              needRefreshSelectedItem: true,
            );
          default:
            result = controller.refreshData();
        }
        await expectLater(result, throwsA(isA<NsgOperationCancelled>()));
        expect(controller.currentStatus, same(previous));
      },
    );
  }
  test(
    'REVIEW cancelled older controller request cannot restore over newer data',
    () async {
      NsgDataClient.client.registerDataItem(
        _Row(),
        remoteProvider: _Provider(),
      );
      final controller = _ControlledController();
      controller.currentStatus = GetStatus.success(NsgBaseController.emptyData);
      final first = controller.refreshData();
      final firstCheck = expectLater(
        first,
        throwsA(isA<NsgOperationCancelled>()),
      );
      final second = controller.refreshData();
      final newest = _Row()..id = 'newest';
      controller.requests[1].complete([newest]);
      await second;
      controller.requests[0].completeError(const NsgOperationCancelled());
      await firstCheck;
      expect(controller.currentStatus.isSuccess, isTrue);
      expect(controller.dataItemList.single, same(newest));
    },
  );
  test(
    'REVIEW scope expires for periodic timers after its future completes',
    () async {
      final token = NsgCancelToken();
      final tick = Completer<NsgCancelToken?>();
      var completed = false;
      late Timer timer;
      final result = NsgCancelToken.runScoped(token, () async {
        timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
          if (completed && !tick.isCompleted) {
            tick.complete(NsgCancelToken.current);
            timer.cancel();
          }
        });
        return 7;
      });
      expect(await result, 7);
      completed = true;
      token.calcel();
      addTearDown(timer.cancel);
      expect(await tick.future.timeout(const Duration(seconds: 2)), isNull);
    },
  );
  test(
    'REVIEW scope expires for stream listeners after its future completes',
    () async {
      final token = NsgCancelToken();
      final stream = StreamController<int>();
      final received = Completer<NsgCancelToken?>();
      late StreamSubscription<int> subscription;
      await NsgCancelToken.runScoped(token, () async {
        subscription = stream.stream.listen(
          (_) => received.complete(NsgCancelToken.current),
        );
      });
      token.calcel();
      stream.add(1);
      expect(await received.future.timeout(const Duration(seconds: 2)), isNull);
      await subscription.cancel();
      await stream.close();
    },
  );
  test(
    'REVIEW ordinary overlapping data reads do not create or cancel a token',
    () async {
      final provider = _Provider()..pending = Completer<dynamic>();
      NsgDataClient.client.registerDataItem(_Row(), remoteProvider: provider);
      final firstGate = provider.pending!;
      final request = NsgDataRequest<_Row>();
      final first = request.requestItems(loadReference: [], autoRepeate: false);
      final firstCheck = expectLater(first, completes);
      provider.pending = Completer<dynamic>();
      final secondGate = provider.pending!;
      final second = request.requestItems(
        loadReference: [],
        autoRepeate: false,
      );
      final secondCheck = expectLater(second, completes);
      firstGate.complete({'results': []});
      secondGate.complete({'results': []});
      await Future.wait([firstCheck, secondCheck]);
      expect(provider.seenTokens, [null, null]);
      expect(request.cancelToken, isNull);
    },
  );
  test('REVIEW data request preserves a manually assigned token', () async {
    final provider = _Provider();
    NsgDataClient.client.registerDataItem(_Row(), remoteProvider: provider);
    final token = NsgCancelToken();
    final request = NsgDataRequest<_Row>()..cancelToken = token;
    await request.requestItems(loadReference: [], autoRepeate: false);
    expect(provider.seen, same(token));
    expect(request.cancelToken, same(token));
  });
  test(
    'REVIEW referent loader rethrows cancellation instead of swallowing LAR-375',
    () async {
      NsgDataClient.client.registerDataItem(
        _RefRow(),
        remoteProvider: _Provider()..failure = const NsgOperationCancelled(),
      );
      NsgDataClient.client.registerDataItem(
        _OwnerRow(),
        remoteProvider: _Provider(),
      );
      final owner = _OwnerRow()
        ..id = 'cancel-owner'
        ..setFieldValue('refId', 'cancel-ref');
      await expectLater(
        NsgDataRequest<_OwnerRow>().loadAllReferents([owner], ['refId']),
        throwsA(isA<NsgOperationCancelled>()),
      );
    },
  );
  test(
    'REVIEW controller cancellation preserves its successful status and rows',
    () async {
      NsgDataClient.client.registerDataItem(
        _Row(),
        remoteProvider: _Provider(),
      );
      final controller = _CancellingController();
      final status = GetStatus.success(NsgBaseController.emptyData);
      final row = _Row()..id = 'kept-draft';
      controller.currentStatus = status;
      controller.dataItemList = [row];
      await expectLater(
        controller.refreshData(),
        throwsA(isA<NsgOperationCancelled>()),
      );
      expect(controller.currentStatus, same(status));
      expect(controller.dataItemList.single, same(row));
    },
  );
  test(
    'cancel during referent hydration does not return a successful result',
    () async {
      NsgDataClient.client.registerDataItem(
        _Row(),
        remoteProvider: _Provider(),
      );
      final request = _HydratingRequest();
      final token = NsgCancelToken();
      final done = request.requestItems(
        loadReference: [],
        autoRepeate: false,
        cancelToken: token,
      );
      final check = expectLater(done, throwsA(isA<NsgOperationCancelled>()));
      await request.started.future;
      token.calcel();
      request.gate.complete();
      await check;
      expect(request.inherited, same(token));
    },
  );
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
