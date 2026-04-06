import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/riverpod/core/notifier/nsg_edit_notifier.dart';
import 'package:nsg_data/riverpod/core/repository/nsg_entity_repository.dart';
import 'package:nsg_data/riverpod/core/repository/nsg_fetch_result.dart';
import 'package:nsg_data/riverpod/core/state/nsg_edit_state.dart';

import '../../../test_support/test_data_item.dart';

class _FakeRepository implements NsgEntityRepository<TestDataItem> {
  @override
  Type get dataType => TestDataItem;

  @override
  Future<TestDataItem> cloneAsDraft(TestDataItem item) async =>
      item.clone() as TestDataItem;

  @override
  Future<TestDataItem> createDraft() async =>
      makeTestDataItem(id: 'created', name: 'Created');

  @override
  Future<void> delete(TestDataItem item) async {}

  @override
  Future<void> deleteMany(List<TestDataItem> items) async {}

  @override
  Future<TestDataItem> fetchItem(
    String id, {
    List<String>? referenceList,
  }) async => makeTestDataItem(id: id, name: 'Loaded');

  @override
  Future<NsgFetchResult<TestDataItem>> fetchList(query) {
    throw UnimplementedError();
  }

  @override
  Future<TestDataItem> save(TestDataItem item) async =>
      item.clone() as TestDataItem;
}

final _fakeRepositoryProvider = Provider<NsgEntityRepository<TestDataItem>>(
  (ref) => _FakeRepository(),
);

class _TestEditNotifier extends NsgEditNotifier<TestDataItem> {
  @override
  ProviderListenable<NsgEntityRepository<TestDataItem>>
  get repositoryProvider => _fakeRepositoryProvider;

  @override
  NsgEditState<TestDataItem> build(NsgEditArg arg) {
    return NsgEditState<TestDataItem>(
      draft: makeTestDataItem(id: 'draft', name: 'Draft'),
    );
  }
}

final _testEditProvider =
    AutoDisposeNotifierProviderFamily<
      _TestEditNotifier,
      NsgEditState<TestDataItem>,
      NsgEditArg
    >(_TestEditNotifier.new);

void main() {
  setUpAll(ensureTestDataItemRegistered);

  test('constructor clones original and draft', () {
    final original = makeTestDataItem(id: '1', name: 'Original');
    final draft = makeTestDataItem(id: '2', name: 'Draft');

    final state = NsgEditState<TestDataItem>(original: original, draft: draft);

    expect(identical(state.original, original), isFalse);
    expect(identical(state.draft, draft), isFalse);
    expect(state.original!.isEqual(original), isTrue);
    expect(state.draft!.isEqual(draft), isTrue);
  });

  test('withDraft clones by default but can trust a prepared draft', () {
    final state = NsgEditState<TestDataItem>(
      draft: makeTestDataItem(id: '1', name: 'Before'),
    );
    final updated = makeTestDataItem(id: '1', name: 'After');

    final clonedState = state.withDraft(updated);
    final trustedState = state.withDraft(updated, trusted: true);

    expect(identical(clonedState.draft, updated), isFalse);
    expect(clonedState.draft!.isEqual(updated), isTrue);
    expect(identical(trustedState.draft, updated), isTrue);
  });

  test('withOriginalAndDraft supports trusted ownership transfer', () {
    final baseState = NsgEditState<TestDataItem>();
    final original = makeTestDataItem(id: '1', name: 'Original');
    final draft = makeTestDataItem(id: '1', name: 'Draft');

    final clonedState = baseState.withOriginalAndDraft(
      original: original,
      draft: draft,
    );
    final trustedState = baseState.withOriginalAndDraft(
      original: original,
      draft: draft,
      trusted: true,
    );

    expect(identical(clonedState.original, original), isFalse);
    expect(identical(clonedState.draft, draft), isFalse);
    expect(identical(trustedState.original, original), isTrue);
    expect(identical(trustedState.draft, draft), isTrue);
  });

  test('copyWith still protects draft by cloning', () {
    final state = NsgEditState<TestDataItem>();
    final draft = makeTestDataItem(id: '1', name: 'Draft');

    final updated = state.copyWith(draft: draft);

    expect(identical(updated.draft, draft), isFalse);
    expect(updated.draft!.isEqual(draft), isTrue);
  });

  test('notifier updateDraft keeps returned prepared draft', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = _testEditProvider(const NsgEditArgCreate());
    final notifier = container.read(provider.notifier);
    final preparedDraft =
        container.read(provider).draft!.clone() as TestDataItem
          ..name = 'Updated';

    notifier.updateDraft((_) => preparedDraft);

    final state = container.read(provider);
    expect(identical(state.draft, preparedDraft), isTrue);
    expect(state.draft!.name, 'Updated');
  });
}
