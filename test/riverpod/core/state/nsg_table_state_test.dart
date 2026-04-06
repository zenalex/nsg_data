import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/riverpod/core/state/nsg_table_state.dart';

import '../../../test_support/table_part_fixtures.dart';

void main() {
  setUpAll(ensureTablePartFixturesRegistered);

  test('seededFromOwner clones rows and metadata', () {
    final row = makeTablePartRow(id: 'r1', label: 'a');
    final owner = makeTablePartOwner(id: 'o1', rows: [row]);

    final state = NsgTableState.initial<TablePartRow>().seededFromOwner(
      owner,
      TablePartOwner.nameRows,
    );

    expect(state.rows, hasLength(1));
    expect(state.rows.first.isEqual(row), isTrue);
    expect(identical(state.rows.first, row), isFalse);
    expect(state.ownerId, 'o1');
    expect(state.tableFieldName, TablePartOwner.nameRows);
    expect(state.dirty, isFalse);
  });
}
