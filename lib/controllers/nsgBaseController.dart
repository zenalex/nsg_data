import 'package:nsg_data/controllers/nsgBaseControllerData.dart';
import 'package:nsg_data/controllers/nsgDataBinding.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
import 'package:retry/retry.dart';

class NsgBaseController extends GetxController
    with StateMixin<NsgBaseControllerData> {
  Type dataType;
  bool requestOnInit;

  ///Use update method on data update
  bool useUpdate;

  ///Use change method on data update
  bool useChange;

  ///GetBuilder IDs to update
  List<String> builderIDs;

  ///Master controller. Using for binding.
  NsgBaseController masterController;

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
    if (_selectedItem != newItem && selectedItemChanged != null) {
      selectedItemChanged(newItem);
    }
    _selectedItem = newItem;
  }

  List<NsgDataItem> dataItemList;

  //Referenses to load
  List<String> referenceList;
  void Function(NsgDataItem selectedItem) selectedItemChanged;

  NsgBaseController(
      {this.dataType,
      this.requestOnInit = true,
      this.useUpdate = false,
      this.useChange = true,
      this.builderIDs,
      this.masterController,
      this.dataBinding,
      this.autoRepeate = false,
      this.autoRepeateCount = 10})
      : super();

  @override
  void onInit() {
    super.onInit();
    if (requestOnInit) requestItems();
  }

  List<NsgDataItem> _itemList;
  List<NsgDataItem> get itemList {
    if (_itemList == null) {
      _itemList = <NsgDataItem>[];
      requestItems();
    }
    return _itemList;
  }

  ///Request Items
  void requestItems() async {
    if (autoRepeate) {
      final r = RetryOptions(maxAttempts: autoRepeateCount);
      await r.retry(() => _requestItems(),
          onRetry: (error) => _updateStatusError(error.toString()));
    } else {
      _requestItems();
    }
  }

  void _requestItems() async {
    try {
      assert(dataType != null);
      var request = NsgDataRequest(dataItemType: dataType);
      var newItemsList = await request.requestItems(
          filter: getRequestFilter, loadReference: referenceList);
      //service method for descendants
      currentStatus = RxStatus.success();
      afterRequestItems(newItemsList);
      dataItemList = filter(newItemsList);
      //notify builders
      if (useUpdate) update(builderIDs);
      if (useChange) {
        change(NsgBaseControllerData(controller: this), status: currentStatus);
      }
      //service method for descendants
      afterUpdate();
    } catch (e) {
      _updateStatusError(e.toString());
    }
  }

  ///is calling after new Items are putted in itemList
  void afterUpdate() {}

  ///is calling after new items are got from API before they are placed to ItemList
  void afterRequestItems(List<NsgDataItem> newItemsList) {}

  List<NsgDataItem> filter(List<NsgDataItem> newItemsList) {
    if (dataBinding == null) return newItemsList;
    if (masterController.selectedItem == null &&
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

  NsgDataRequestFilter get getRequestFilter => null;

  void _updateStatusError(String e) {
    currentStatus = RxStatus.error(e.toString());
    if (useUpdate) update(builderIDs);
    if (useChange) {
      change(null, status: currentStatus);
    }
  }
}
