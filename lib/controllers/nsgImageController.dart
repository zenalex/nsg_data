import 'package:nsg_data/nsg_data.dart';

class NsgImageController<T extends NsgDataItem> extends NsgDataController<T> {
  NsgImageController(
      {super.requestOnInit = true,
      super.masterController,
      super.dataBindign,
      super.autoRepeate = false,
      super.autoRepeateCount = 10,
      super.useDataCache = true,
      super.selectedMasterRequired = true,
      super.autoSelectFirstItem = false,
      super.dependsOnControllers});
}
