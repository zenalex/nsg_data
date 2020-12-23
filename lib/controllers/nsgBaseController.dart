import 'package:event/event.dart';
import 'package:nsg_data/controllers/nsgBaseControllerData.dart';
import 'package:nsg_data/controllers/nsgDataBinding.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
import 'package:retry/retry.dart';

//TODO: запрос данных с фильтром
class NsgBaseController extends GetxController
    with StateMixin<NsgBaseControllerData> {
  Type dataType;
  bool requestOnInit;
  bool selectedMasterRequired;
  bool useDataCache;
  bool autoSelectFirstItem;

  List<NsgDataItem> dataItemList;
  List<NsgDataItem> dataCache;

  //Referenses to load
  List<String> referenceList;
  final selectedItemChanged = Event<GenericEventArgs1>();
  final itemsRequested = Event<GenericEventArgs1>();

  ///Use update method on data update
  bool useUpdate;

  ///Use change method on data update
  bool useChange;

  ///GetBuilder IDs to update
  List<String> builderIDs;

  ///Master controller. Using for binding.
  NsgBaseController masterController;
  List<NsgBaseController> dependsOnControllers;

  ///Binding rule
  NsgDataBinding dataBinding;

  ///Status of last data request operation
  RxStatus currentStatus = RxStatus.loading();

  ///Enable auto repeate attempts of requesting data
  bool autoRepeate;

  ///Set count of attempts of requesting data
  int autoRepeateCount;

  NsgDataItem _selectedItem;
  NsgDataItem get selectedItem => _selectedItem;
  set selectedItem(NsgDataItem newItem) {
    var oldItem = _selectedItem;
    if (_selectedItem != newItem) {
      _selectedItem = newItem;
      selectedItemChanged.broadcast(GenericEventArgs1(oldItem));
      sendNotify();
    }
  }

  NsgBaseController(
      {this.dataType,
      this.requestOnInit = false,
      this.useUpdate = false,
      this.useChange = true,
      this.builderIDs,
      this.masterController,
      this.selectedMasterRequired = true,
      this.dataBinding,
      this.autoRepeate = false,
      this.autoRepeateCount = 10,
      this.useDataCache = false,
      this.autoSelectFirstItem = false,
      dependsOnControllers})
      : super();

  @override
  void onInit() {
    if (masterController != null) {
      masterController.selectedItemChanged.subscribe(masterValueChanged);
    }
    if (dependsOnControllers != null) {
      dependsOnControllers.forEach((element) {
        element.selectedItemChanged.subscribe(masterValueChanged);
      });
    }

    if (requestOnInit) requestItems();
    super.onInit();
  }

  @override
  void onClose() {
    if (masterController != null) {
      masterController.selectedItemChanged.unsubscribe(masterValueChanged);
    }
    if (dependsOnControllers != null) {
      dependsOnControllers.forEach((element) {
        element.selectedItemChanged.unsubscribe(masterValueChanged);
      });
    }
  }
  // List<NsgDataItem> _itemList;
  // List<NsgDataItem> get itemList {
  //   if (_itemList == null) {
  //     _itemList = <NsgDataItem>[];
  //     requestItems();
  //   }
  //   return _itemList;
  // }

  ///Request Items
  Future requestItems() async {
    if (autoRepeate) {
      final r = RetryOptions(maxAttempts: autoRepeateCount);
      await r.retry(() => _requestItems(),
          onRetry: (error) => _updateStatusError(error.toString()));
    } else {
      await _requestItems();
    }
  }

  Future _requestItems() async {
    try {
      assert(dataType != null);
      if (masterController != null &&
          selectedMasterRequired &&
          masterController.selectedItem == null) {
        if (dataItemList != null && dataItemList.isNotEmpty) {
          dataItemList.clear();
        }
        return;
      }
      List<NsgDataItem> newItemsList;
      if (useDataCache && dataCache != null) {
        newItemsList = dataCache;
      } else {
        newItemsList = await doRequestItems();

        //service method for descendants
        currentStatus = RxStatus.success();
        afterRequestItems(newItemsList);
        if (useDataCache) dataCache = newItemsList;
      }
      dataItemList = filter(newItemsList);
      if (!dataItemList.contains(selectedItem)) selectedItem = null;
      //notify builders
      sendNotify();
      if (selectedItem == null &&
          autoSelectFirstItem &&
          dataItemList != null &&
          dataItemList.isNotEmpty) {
        selectedItem = dataItemList[0];
      }
      //service method for descendants
      afterUpdate();
    } catch (e) {
      _updateStatusError(e.toString());
    }
  }

  void sendNotify() {
    if (useUpdate) update(builderIDs);
    if (useChange) {
      change(NsgBaseControllerData(controller: this), status: currentStatus);
    }
  }

  Future<List<NsgDataItem>> doRequestItems() async {
    var request = NsgDataRequest(dataItemType: dataType);
    return await request.requestItems(
        filter: getRequestFilter, loadReference: referenceList);
  }

  ///is calling after new Items are putted in itemList
  void afterUpdate() {}

  ///is calling after new items are got from API before they are placed to ItemList
  void afterRequestItems(List<NsgDataItem> newItemsList) {}

  List<NsgDataItem> filter(List<NsgDataItem> newItemsList) {
    if (dataBinding == null) return newItemsList;
    if (masterController.selectedItem == null ||
        !masterController.selectedItem.fieldList.fields
            .containsKey(dataBinding.masterFieldName)) return newItemsList;
    var masterValue = masterController
        .selectedItem.fieldValues.fields[dataBinding.masterFieldName];

    var list = <NsgDataItem>[];
    newItemsList.forEach((element) {
      if (element.fieldValues.fields[dataBinding.slaveFieldName] ==
          masterValue) {
        list.add(element);
      }
    });
    return list;
  }

  bool matchFilter(NsgDataItem item) {
    var list = [item];
    return filter(list).isNotEmpty;
  }

  NsgDataRequestParams get getRequestFilter => null;

  void _updateStatusError(String e) {
    currentStatus = RxStatus.error(e.toString());
    if (useUpdate) update(builderIDs);
    if (useChange) {
      change(null, status: currentStatus);
    }
  }

  void masterValueChanged(GenericEventArgs1 args) async {
    //if (!matchFilter(selectedItem)) selectedItem = null;
    await requestItems();
  }
}
