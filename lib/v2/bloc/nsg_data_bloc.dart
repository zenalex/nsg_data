import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/view/nsg_view_controller.dart';

sealed class NsgDataBlocEvent<T extends NsgDataItem> {
  const NsgDataBlocEvent();
}

final class NsgDataRefreshEvent<T extends NsgDataItem> extends NsgDataBlocEvent<T> {
  /// When non-null, replaces the controller's request params before refresh.
  final NsgDataRequestParams? params;

  /// When non-null, replaces the controller's load reference before refresh.
  final Iterable<String>? loadReference;

  const NsgDataRefreshEvent({this.params, this.loadReference});
}

final class NsgDataSelectEvent<T extends NsgDataItem> extends NsgDataBlocEvent<T> {
  final T? item;
  final bool saveAsBackup;

  const NsgDataSelectEvent(this.item, {this.saveAsBackup = false});
}

final class NsgDataCreateEvent<T extends NsgDataItem> extends NsgDataBlocEvent<T> {
  /// When true, the created item is immediately set as [selectedItem].
  final bool selectCreated;
  final bool saveAsBackup;

  const NsgDataCreateEvent({this.selectCreated = true, this.saveAsBackup = true});
}

final class NsgDataSaveSelectedEvent<T extends NsgDataItem> extends NsgDataBlocEvent<T> {
  final Iterable<String>? loadReference;

  const NsgDataSaveSelectedEvent({this.loadReference});
}

final class NsgDataDeleteSelectedEvent<T extends NsgDataItem> extends NsgDataBlocEvent<T> {
  const NsgDataDeleteSelectedEvent();
}

final class _NsgDataSyncEvent<T extends NsgDataItem> extends NsgDataBlocEvent<T> {
  final NsgControllerSnapshot<T> snapshot;

  const _NsgDataSyncEvent(this.snapshot);
}

/// BLoC adapter for [NsgViewControllerV2].
///
/// Mirrors the controller's **main list** snapshot as bloc state. Selection
/// state ([selectedStore] / [backupStore]) is NOT mirrored — observe it via
/// [NsgViewControllerV2.selectedItemsUpdates] or
/// [NsgViewControllerV2.observeStatus] directly.
///
/// When [disposeControllerOnClose] is `true` (default), [close] disposes the
/// [NsgViewControllerV2]. The underlying [NsgDataControllerV2] is NOT
/// disposed automatically — manage it via DI or the composition root.
class NsgDataBloc<T extends NsgDataItem> extends Bloc<NsgDataBlocEvent<T>, NsgControllerSnapshot<T>> {
  final NsgViewControllerV2<T> controller;
  final bool disposeControllerOnClose;
  StreamSubscription<NsgControllerSnapshot<T>>? _subscription;

  NsgDataBloc({required this.controller, this.disposeControllerOnClose = true}) : super(controller.snapshot) {
    on<NsgDataRefreshEvent<T>>(_onRefresh);
    on<NsgDataSelectEvent<T>>(_onSelect);
    on<NsgDataCreateEvent<T>>(_onCreate);
    on<NsgDataSaveSelectedEvent<T>>(_onSaveSelected);
    on<NsgDataDeleteSelectedEvent<T>>(_onDeleteSelected);
    on<_NsgDataSyncEvent<T>>(_onSync);
    _subscription = controller.itemsUpdates.listen((snapshot) {
      if (!isClosed) add(_NsgDataSyncEvent<T>(snapshot));
    });
  }

  Future<void> init() async {
    await controller.init();
  }

  /// Optionally persists [event.params] and [event.loadReference] into the
  /// controller snapshot via [replaceRequestParams], then triggers a refresh.
  Future<void> _onRefresh(NsgDataRefreshEvent<T> event, Emitter<NsgControllerSnapshot<T>> emit) async {
    final hasParams = event.params != null;
    final hasRef = event.loadReference != null;
    if (hasParams || hasRef) {
      controller.dataController.replaceRequestParams(
        event.params ?? controller.requestParams,
        loadReference: event.loadReference,
      );
    }
    await controller.refresh();
  }

  Future<void> _onSelect(NsgDataSelectEvent<T> event, Emitter<NsgControllerSnapshot<T>> emit) async {
    controller.select(event.item, saveAsBackup: event.saveAsBackup);
  }

  Future<void> _onCreate(NsgDataCreateEvent<T> event, Emitter<NsgControllerSnapshot<T>> emit) async {
    if (event.selectCreated) {
      await controller.createAndSelect(saveAsBackup: event.saveAsBackup);
      return;
    }
    await controller.create();
  }

  Future<void> _onSaveSelected(NsgDataSaveSelectedEvent<T> event, Emitter<NsgControllerSnapshot<T>> emit) async {
    await controller.saveSelected(loadReference: event.loadReference);
  }

  Future<void> _onDeleteSelected(NsgDataDeleteSelectedEvent<T> event, Emitter<NsgControllerSnapshot<T>> emit) async {
    await controller.deleteSelected();
  }

  void _onSync(_NsgDataSyncEvent<T> event, Emitter<NsgControllerSnapshot<T>> emit) {
    emit(event.snapshot);
  }

  /// Cancels the snapshot subscription before closing so in-flight stream
  /// events cannot call [add] on an already-closed bloc.
  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    if (disposeControllerOnClose) {
      await controller.dispose();
    }
    return super.close();
  }
}
