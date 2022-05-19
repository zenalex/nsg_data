import 'package:nsg_data/nsg_data.dart';

class NsgDataController<T extends NsgDataItem> extends NsgBaseController {
  List<T> get items => dataItemList.cast<T>();
  T get firstItem => (dataItemList.isEmpty) ? NsgDataClient.client.getNewObject(dataType) as T : items[0];
  T get currentItem => ((selectedItem ?? NsgDataClient.client.getNewObject(dataType)) as T);
  set currentItem(T item) => selectedItem = item;

  NsgDataController(
      {bool requestOnInit = true,
      bool useUpdate = false,
      bool useChange = true,
      List<String>? builderIDs,
      NsgBaseController? masterController,
      NsgDataBinding? dataBindign,
      bool autoRepeate = false,
      int autoRepeateCount = 10,
      bool useDataCache = false,
      bool selectedMasterRequired = true,
      bool autoSelectFirstItem = false,
      List<NsgBaseController>? dependsOnControllers})
      : super(
            dataType: T,
            requestOnInit: requestOnInit,
            useUpdate: useUpdate,
            useChange: useChange,
            builderIDs: builderIDs,
            masterController: masterController,
            dataBinding: dataBindign,
            autoRepeate: autoRepeate,
            autoRepeateCount: autoRepeateCount,
            selectedMasterRequired: selectedMasterRequired,
            useDataCache: useDataCache,
            autoSelectFirstItem: autoSelectFirstItem,
            dependsOnControllers: dependsOnControllers);

  ///Сделать текущим предыдущий элемент
  void gotoPrevItem() {
    var index = items.indexOf(currentItem);
    if (index == 0) return;
    currentItem = items[index - 1];
    refreshSelectedItem(null);
  }

  ///Сделать текущим следующий элемент
  void gotoNextItem() {
    var index = items.indexOf(currentItem);
    if (index >= items.length - 1) return;
    currentItem = items[index + 1];
    refreshSelectedItem(null);
  }

  ///Есть ли в списке элементы до текущего
  bool canGoPrevItem() {
    var index = items.indexOf(currentItem);
    return index > 0;
  }

  ///Есть ли в списке элементы после текущего
  bool canGoNextItem() {
    var index = items.indexOf(currentItem);
    return index >= 0 && index < items.length - 1;
  }

  T createNewItem() {
    return NsgDataClient.client.getNewObject(dataType) as T;
  }
}
