import 'dart:async';

import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/snapshot.dart';
import 'package:nsg_data/v2/abstract/store.dart';
import 'package:nsg_data/v2/base/nsg_lifecycle.dart';
import 'package:nsg_data/v2/controller/nsg_controller_snapshot.dart';

mixin NsgControllerStoreMixin<S extends Snapshot, T extends NsgDataItem> implements NsgLifecycle, Store {
  final StreamController<S> _streamController = StreamController<S>.broadcast();
  bool _disposed = false;

  Stream<S> get stream => _streamController.stream;

  @override
  void update(covariant S next) {
    snapshot = next;
    if (!_disposed) {
      _streamController.add(next);
    }
  }

  @override
  void init() {}

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _streamController.close();
  }
}

class NsgControllerStore<T extends NsgDataItem> with NsgControllerStoreMixin<NsgControllerSnapshot<T>, T> implements Store {
  @override
  NsgControllerSnapshot<T> snapshot = NsgControllerSnapshot<T>.empty();
}
