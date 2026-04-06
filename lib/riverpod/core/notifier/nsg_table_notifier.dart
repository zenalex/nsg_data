import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/riverpod/core/state/nsg_table_state.dart';

/// Riverpod-friendly table-part editor: in-memory row list with explicit apply to master.
class NsgTableNotifier<T extends NsgDataItem> extends Notifier<NsgTableState<T>> {
  @override
  NsgTableState<T> build() {
    return NsgTableState.initial<T>();
  }

  void seedFromRows(
    Iterable<T> rows, {
    String? ownerId,
    String? tableFieldName,
  }) {
    state = state.copyWith(
      rows: rows,
      ownerId: ownerId ?? state.ownerId,
      tableFieldName: tableFieldName ?? state.tableFieldName,
      selectedRowId: null,
      dirty: false,
      error: null,
      stackTrace: null,
    );
  }

  void seedFromOwner(NsgDataItem owner, String fieldName) {
    state = state.seededFromOwner(owner, fieldName);
  }

  void selectRow(String? id) {
    state = state.copyWith(selectedRowId: id);
  }

  void upsertRow(T row) {
    final id = row.id;
    final list = state.rows.toList();
    final idx = list.indexWhere((e) => e.id == id);
    final clone = row.clone() as T;
    if (idx >= 0) {
      list[idx] = clone;
    } else {
      list.add(clone);
    }
    state = state.copyWith(rows: list, dirty: true);
  }

  bool removeRowById(String id) {
    final list = state.rows.where((e) => e.id != id).toList();
    if (list.length == state.rows.length) return false;
    state = state.copyWith(
      rows: list,
      selectedRowId: state.selectedRowId == id ? null : state.selectedRowId,
      dirty: true,
    );
    return true;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.rows.length) return;
    var to = newIndex;
    if (to < 0 || to > state.rows.length) return;
    if (oldIndex < to) to -= 1;
    final list = state.rows.toList();
    final item = list.removeAt(oldIndex);
    list.insert(to, item);
    state = state.copyWith(rows: list, dirty: true);
  }

  /// Writes current rows onto [owner] (replaces list field). Caller supplies same [fieldName] used when seeding.
  void applyToOwner(NsgDataItem owner, String fieldName) {
    owner.setFieldValue(
      fieldName,
      state.rows.map((e) => e.clone()).toList(),
    );
    state = state.copyWith(
      ownerId: owner.id,
      tableFieldName: fieldName,
      dirty: false,
    );
  }

  void resetTo(Iterable<T> rows) {
    state = state.copyWith(
      rows: rows,
      dirty: false,
      error: null,
      stackTrace: null,
    );
  }

  void clearError() {
    state = state.copyWith(error: null, stackTrace: null);
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// Exposed for app-level bridge helpers (avoid reading [state] from extensions).
  bool get hasPendingTableChanges => state.dirty;
}
