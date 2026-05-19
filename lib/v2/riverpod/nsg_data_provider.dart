import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/view/nsg_view_controller.dart';
import 'package:riverpod/riverpod.dart';

class NsgDataStateNotifier<T extends NsgDataItem> extends StateNotifier<NsgControllerSnapshot<T>> {
  final NsgViewControllerV2<T> controller;
  final bool disposeControllerOnDispose;
  StreamSubscription<NsgControllerSnapshot<T>>? _subscription;
  bool _disposed = false;

  NsgDataStateNotifier({required this.controller, this.disposeControllerOnDispose = true}) : super(controller.snapshot) {
    _subscription = controller.itemsUpdates.listen((snapshot) {
      state = snapshot;
    });
  }

  Future<void> init() async {
    await controller.init();
  }

  Future<void> refresh({NsgDataRequestParams? params, Iterable<String>? loadReference}) async {
    if (params != null) {
      controller.dataController.replaceRequestParams(params, loadReference: loadReference);
    }
    await controller.refresh(loadReference: loadReference);
  }

  void select(T? item, {bool saveAsBackup = false}) {
    controller.select(item, saveAsBackup: saveAsBackup);
  }

  Future<T> create({bool selectCreated = true, bool saveAsBackup = true}) async {
    if (selectCreated) {
      return controller.createAndSelect(saveAsBackup: saveAsBackup);
    }
    return controller.create();
  }

  Future<T?> saveSelected({Iterable<String>? loadReference}) async {
    return controller.saveSelected(loadReference: loadReference);
  }

  Future<void> deleteSelected() async {
    await controller.deleteSelected();
  }

  /// Riverpod calls [dispose] automatically when the [StateNotifierProvider] is
  /// destroyed. A [_disposed] guard prevents double-dispose if this method is
  /// ever invoked manually before the provider teardown.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    if (disposeControllerOnDispose) {
      unawaited(Future.sync(() => controller.dispose()));
    }
    super.dispose();
  }
}

/// Creates an [AutoDisposeStateNotifierProvider] that owns the given
/// [controller] and forwards its main-list [NsgControllerSnapshot] as
/// Riverpod state.
///
/// Riverpod disposes the [StateNotifier] automatically — do **not** add
/// `ref.onDispose(notifier.dispose)` inside the factory; that would cause a
/// double-dispose.
AutoDisposeStateNotifierProvider<NsgDataStateNotifier<T>, NsgControllerSnapshot<T>> nsgDataProvider<T extends NsgDataItem>({
  required NsgViewControllerV2<T> controller,
  bool disposeControllerOnDispose = true,
}) {
  return StateNotifierProvider.autoDispose<NsgDataStateNotifier<T>, NsgControllerSnapshot<T>>((ref) {
    final notifier = NsgDataStateNotifier<T>(controller: controller, disposeControllerOnDispose: disposeControllerOnDispose);
    // Riverpod calls StateNotifier.dispose() automatically on provider teardown.
    // Adding ref.onDispose(notifier.dispose) here would trigger a double-dispose.
    unawaited(notifier.init());
    return notifier;
  });
}
