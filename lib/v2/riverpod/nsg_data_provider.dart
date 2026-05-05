import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';
import 'package:nsg_data/v2/controller/view/nsg_view_controller.dart';
import 'package:riverpod/riverpod.dart';

class NsgDataStateNotifier<T extends NsgDataItem> extends StateNotifier<NsgControllerSnapshot<T>> {
  final NsgViewControllerV2<T> controller;
  final bool disposeControllerOnDispose;
  StreamSubscription<NsgControllerSnapshot<T>>? _subscription;

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

  @override
  void dispose() {
    _subscription?.cancel();
    if (disposeControllerOnDispose) {
      unawaited(Future.sync(() => controller.dispose()));
    }
    super.dispose();
  }
}

AutoDisposeStateNotifierProvider<NsgDataStateNotifier<T>, NsgControllerSnapshot<T>> nsgDataProvider<T extends NsgDataItem>({
  required NsgViewControllerV2<T> controller,
  bool disposeControllerOnDispose = true,
}) {
  return StateNotifierProvider.autoDispose<NsgDataStateNotifier<T>, NsgControllerSnapshot<T>>((ref) {
    final notifier = NsgDataStateNotifier<T>(controller: controller, disposeControllerOnDispose: disposeControllerOnDispose);
    ref.onDispose(notifier.dispose);
    unawaited(notifier.init());
    return notifier;
  });
}
