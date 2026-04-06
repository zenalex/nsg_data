import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/riverpod/core/query/nsg_list_query.dart';
import 'package:nsg_data/riverpod/core/state/nsg_list_state.dart';

import '../../../test_support/test_data_item.dart';

void main() {
  setUpAll(ensureTestDataItemRegistered);

  test('constructor clones items', () {
    final source = makeTestDataItem(id: '1', name: 'Source');

    final state = NsgListState<TestDataItem>(items: [source]);

    expect(state.items, hasLength(1));
    expect(identical(state.items.first, source), isFalse);
    expect(state.items.first.isEqual(source), isTrue);
  });

  test(
    'copyWith clones incoming items but preserves existing trusted view',
    () {
      final source = makeTestDataItem(id: '1', name: 'Source');
      final state = NsgListState<TestDataItem>(items: [source]);

      final replacement = makeTestDataItem(id: '2', name: 'Replacement');
      final updated = state.copyWith(items: [replacement]);
      final unchanged = state.copyWith(query: NsgListQuery());

      expect(identical(updated.items.first, replacement), isFalse);
      expect(updated.items.first.isEqual(replacement), isTrue);
      expect(identical(unchanged.items, state.items), isTrue);
    },
  );
}
