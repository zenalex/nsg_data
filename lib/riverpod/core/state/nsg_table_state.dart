import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:nsg_data/dataFields/nsg_data_table.dart';
import 'package:nsg_data/nsg_data_item.dart';

const Object _sentinel = Object();

/// Immutable snapshot of an embedded table-part (rows owned by a master item).
class NsgTableState<T extends NsgDataItem> {
  final UnmodifiableListView<T> rows;
  final String? ownerId;
  final String? tableFieldName;
  final String? selectedRowId;
  final bool dirty;
  final bool isLoading;
  final Object? error;
  final StackTrace? stackTrace;

  NsgTableState({
    Iterable<T> rows = const [],
    this.ownerId,
    this.tableFieldName,
    this.selectedRowId,
    this.dirty = false,
    this.isLoading = false,
    this.error,
    this.stackTrace,
  }) : rows = UnmodifiableListView<T>(rows.map((e) => e.clone() as T));

  NsgTableState._trusted({
    required this.rows,
    required this.ownerId,
    required this.tableFieldName,
    required this.selectedRowId,
    required this.dirty,
    required this.isLoading,
    required this.error,
    required this.stackTrace,
  });

  static NsgTableState<T> initial<T extends NsgDataItem>() {
    return NsgTableState<T>._trusted(
      rows: UnmodifiableListView<T>(const []),
      ownerId: null,
      tableFieldName: null,
      selectedRowId: null,
      dirty: false,
      isLoading: false,
      error: null,
      stackTrace: null,
    );
  }

  bool get hasError => error != null;

  NsgTableState<T> copyWith({
    Iterable<T>? rows,
    Object? ownerId = _sentinel,
    Object? tableFieldName = _sentinel,
    Object? selectedRowId = _sentinel,
    bool? dirty,
    bool? isLoading,
    Object? error = _sentinel,
    Object? stackTrace = _sentinel,
  }) {
    return NsgTableState<T>._trusted(
      rows: rows != null
          ? UnmodifiableListView<T>(rows.map((e) => e.clone() as T))
          : this.rows,
      ownerId: identical(ownerId, _sentinel)
          ? this.ownerId
          : ownerId as String?,
      tableFieldName: identical(tableFieldName, _sentinel)
          ? this.tableFieldName
          : tableFieldName as String?,
      selectedRowId: identical(selectedRowId, _sentinel)
          ? this.selectedRowId
          : selectedRowId as String?,
      dirty: dirty ?? this.dirty,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error,
      stackTrace: identical(stackTrace, _sentinel)
          ? this.stackTrace
          : stackTrace as StackTrace?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NsgTableState<T> &&
        listEquals(other.rows, rows) &&
        other.ownerId == ownerId &&
        other.tableFieldName == tableFieldName &&
        other.selectedRowId == selectedRowId &&
        other.dirty == dirty &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(rows),
    ownerId,
    tableFieldName,
    selectedRowId,
    dirty,
    isLoading,
    error,
    stackTrace,
  );
}

extension NsgTableStateOwnerSync<T extends NsgDataItem> on NsgTableState<T> {
  /// Loads row clones from [owner] field (same semantics as [NsgDataTable.rows]).
  NsgTableState<T> seededFromOwner(NsgDataItem owner, String fieldName) {
    final table = NsgDataTable<T>(owner: owner, fieldName: fieldName);
    return copyWith(
      rows: table.rows,
      ownerId: owner.id,
      tableFieldName: fieldName,
      selectedRowId: null,
      dirty: false,
      isLoading: false,
      error: null,
      stackTrace: null,
    );
  }
}
