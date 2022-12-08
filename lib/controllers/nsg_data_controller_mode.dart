class NsgDataControllerMode {
  final NsgDataStorageType storageType;

  const NsgDataControllerMode({this.storageType = NsgDataStorageType.server});

  static var defaultDataControllerMode = const NsgDataControllerMode(storageType : NsgDataStorageType.server);
}

enum NsgDataStorageType { local, server }
