import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsg_data/riverpod/core/notifier/nsg_table_notifier.dart';
import 'package:nsg_data/riverpod/core/state/nsg_table_state.dart';

import '../../../test_support/table_part_fixtures.dart';

final _testTableProvider =
    NotifierProvider<NsgTableNotifier<TablePartRow>, NsgTableState<TablePartRow>>(
      NsgTableNotifier<TablePartRow>.new,
    );

void main() {
  setUpAll(ensureTablePartFixturesRegistered);

  test('upsert remove reorder dirty applyToOwner', () {
    final owner = makeTablePartOwner(id: 'o1', rows: []);
    final container = ProviderContainer();
    final n = container.read(_testTableProvider.notifier);

    n.seedFromOwner(owner, TablePartOwner.nameRows);
    expect(container.read(_testTableProvider).dirty, isFalse);

    n.upsertRow(makeTablePartRow(id: '1', label: 'x'));
    expect(container.read(_testTableProvider).rows, hasLength(1));
    expect(container.read(_testTableProvider).dirty, isTrue);

    n.upsertRow(makeTablePartRow(id: '1', label: 'y'));
    expect(container.read(_testTableProvider).rows.single.label, 'y');

    n.removeRowById('1');
    expect(container.read(_testTableProvider).rows, isEmpty);

    n.seedFromRows([
      makeTablePartRow(id: 'a'),
      makeTablePartRow(id: 'b'),
      makeTablePartRow(id: 'c'),
    ], ownerId: 'o1', tableFieldName: TablePartOwner.nameRows);
    n.reorder(0, 3);
    expect(
      container.read(_testTableProvider).rows.map((e) => e.id).toList(),
      ['b', 'c', 'a'],
    );

    n.applyToOwner(owner, TablePartOwner.nameRows);
    final stored = owner.getFieldValue(TablePartOwner.nameRows) as List;
    expect(stored, hasLength(3));
    expect(container.read(_testTableProvider).dirty, isFalse);

    container.dispose();
  });
}
