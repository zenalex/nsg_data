import 'dart:async';
import 'package:nsg_data/nsg_data.dart';

/// Менеджер синхронизации данных между двумя контроллерами (локальным и серверным)
class NsgDataSyncManager_Disabled<T extends NsgDataItem> extends NsgDataController<T> {
  final NsgDataController<T>? localController;
  final NsgDataController<T>? serverController;

  bool _isSyncing = false;
  Completer<void>? _pendingSync;
  DateTime? _maxSyncedChangeTime;
  bool _localLoaded = false;

  bool get isLocalEnabled => localController != null;
  bool get isServerEnabled => serverController != null;

  NsgDataSyncManager_Disabled({
    required this.localController,
    required this.serverController,
  });

  /// Запуск синхронизации с задержкой (debounce) и защитой от параллельных вызовов
  Future<void> sync({Duration debounce = const Duration(milliseconds: 300)}) async {
    if (_isSyncing) {
      _pendingSync ??= Completer<void>();
      await _pendingSync!.future;
      return;
    }
    _isSyncing = true;
    await Future.delayed(debounce);
    try {
      await _doSync();
    } finally {
      _isSyncing = false;
      _pendingSync?.complete();
      _pendingSync = null;
    }
  }

  /// Основная логика синхронизации
  Future<void> _doSync() async {
    if (isLocalEnabled && !_localLoaded) {
      await localController!.requestItems();
      dataItemList
        ..clear()
        ..addAll(localController!.items);
      _localLoaded = true;
    }
    if (isServerEnabled) {
      await serverController!.requestItems();
    }

    final localMap = isLocalEnabled ? {for (var item in dataItemList.cast<T>()) item.id: item} : <String, T>{};
    final serverMap = isServerEnabled ? {for (var item in serverController!.items) item.id: item} : <String, T>{};

    DateTime maxChange = _maxSyncedChangeTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final allIds = {...localMap.keys, ...serverMap.keys};

    final List<T> toSaveLocal = [];
    final List<T> toSaveServer = [];

    for (final id in allIds) {
      final localItem = localMap[id];
      final serverItem = serverMap[id];

      DateTime? localTime = localItem?.lastChangeTime;
      DateTime? serverTime = serverItem?.lastChangeTime;

      if ((localTime == null || !localTime.isAfter(maxChange)) && (serverTime == null || !serverTime.isAfter(maxChange))) {
        continue;
      }

      if (localItem != null && serverItem != null) {
        if (localItem.lastChangeTime.isAfter(serverItem.lastChangeTime)) {
          if (isServerEnabled) toSaveServer.add(localItem);
        } else if (serverItem.lastChangeTime.isAfter(localItem.lastChangeTime)) {
          localItem.copyFieldValues(serverItem);
          if (isLocalEnabled) toSaveLocal.add(localItem);
        }
      } else if (localItem != null) {
        if (isServerEnabled) toSaveServer.add(localItem);
      } else if (serverItem != null) {
        dataItemList.add(serverItem);
        if (isLocalEnabled) toSaveLocal.add(serverItem);
      }

      if (localTime != null && localTime.isAfter(maxChange)) maxChange = localTime;
      if (serverTime != null && serverTime.isAfter(maxChange)) maxChange = serverTime;
    }

    if (isServerEnabled && toSaveServer.isNotEmpty) {
      await serverController!.postItems(toSaveServer);
    }
    if (isLocalEnabled && toSaveLocal.isNotEmpty) {
      await localController!.postItems(toSaveLocal);
    }

    _maxSyncedChangeTime = maxChange;
  }

  /// Получить максимальную дату синхронизированных изменений
  DateTime? get maxSyncedChangeTime => _maxSyncedChangeTime;

  /// Сбросить максимальную дату синхронизации (например, для полной повторной синхронизации)
  void resetMaxSyncedChangeTime() {
    _maxSyncedChangeTime = null;
  }

  /// Принудительно перечитать локальные данные при следующей синхронизации
  void forceReloadLocal() {
    _localLoaded = false;
  }
}
