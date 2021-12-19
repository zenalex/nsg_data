import 'package:nsg_data/nsg_data.dart';

class NsgDataController<T extends NsgDataItem> extends NsgBaseController {
  List<T> get items => dataItemList.cast<T>();
  T get firstItem => (dataItemList.isEmpty)
      ? NsgDataClient.client.getNewObject(dataType) as T
      : items[0];

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
}
