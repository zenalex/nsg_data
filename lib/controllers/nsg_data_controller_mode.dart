class NsgDataControllerMode {
  final NsgDataStorageType storageType;

  const NsgDataControllerMode({this.storageType = NsgDataStorageType.server});
}

enum NsgDataStorageType { local, server }
