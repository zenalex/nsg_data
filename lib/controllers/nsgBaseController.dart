import 'dart:async';

import 'package:event/event.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
import 'package:retry/retry.dart';

class NsgBaseController extends GetxController
    with StateMixin<NsgBaseControllerData> {
  Type dataType;
  bool requestOnInit;
  bool selectedMasterRequired;
  bool useDataCache;
  bool autoSelectFirstItem;

  List<NsgDataItem> dataItemList = <NsgDataItem>[];
  List<NsgDataItem> dataCache = <NsgDataItem>[];

  //Referenses to load
  List<String>? referenceList;
  final selectedItemChanged = Event<EventArgs>();
  final itemsRequested = Event<EventArgs>();

  ///Use update method on data update
  bool useUpdate;

  ///Use change method on data update
  bool useChange;

  ///GetBuilder IDs to update
  List<String>? builderIDs;

  ///Master controller. Using for binding.
  NsgBaseController? masterController;
  List<NsgBaseController>? dependsOnControllers;

  ///Binding rule
  NsgDataBinding? dataBinding;

  ///Status of last data request operation
  RxStatus currentStatus = RxStatus.loading();

  ///Enable auto repeate attempts of requesting data
  bool autoRepeate;

  ///Set count of attempts of requesting data
  int autoRepeateCount;

  /// If no [retryIf] function is given this will retry any for any [Exception]
  /// thrown. To retry on an [Error], the error must be caught and _rethrown_
  /// as an [Exception].
  FutureOr<bool> Function(Exception)? retryIf;

  /// At every retry the [onRetry] function will be called (if given). The
  /// function [fn] will be invoked at-most [this.attempts] times.
  FutureOr<void> Function(Exception)? onRetry;

  NsgDataItem? _selectedItem;
  NsgDataItem? get selectedItem => _selectedItem;
  set selectedItem(NsgDataItem? newItem) {
    //var oldItem = _selectedItem;
    if (_selectedItem != newItem) {
      _selectedItem = newItem;
      //TODO: передавать в событие значение
      selectedItemChanged.broadcast(null);
      sendNotify();
    }
  }

  NsgBaseController(
      {this.dataType = NsgDataItem,
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
      this.dependsOnControllers,
      this.onRetry,
      this.retryIf})
      : super() {
    onRetry ??= _updateStatusError;
  }

  @override
  void onInit() {
    if (masterController != null) {
      masterController!.selectedItemChanged.subscribe(masterValueChanged);
    }
    if (dependsOnControllers != null) {
      dependsOnControllers!.forEach((element) {
        element.selectedItemChanged.subscribe(masterValueChanged);
      });
    }

    if (requestOnInit) requestItems();
    super.onInit();
  }

  @override
  void onClose() {
    if (masterController != null) {
      masterController!.selectedItemChanged.unsubscribe(masterValueChanged);
    }
    if (dependsOnControllers != null) {
      dependsOnControllers!.forEach((element) {
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
          onRetry: _updateStatusError, retryIf: retryIf);
    } else {
      await _requestItems();
    }
  }

  Future _requestItems() async {
    try {
      if (masterController != null &&
          selectedMasterRequired &&
          masterController!.selectedItem == null) {
        if (dataItemList.isNotEmpty) {
          dataItemList.clear();
        }
        return;
      }
      List<NsgDataItem> newItemsList;
      if (useDataCache && dataCache.isNotEmpty) {
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
          dataItemList.isNotEmpty) {
        selectedItem = dataItemList[0];
      }
      //service method for descendants
      afterUpdate();
    } on Exception catch (e) {
      _updateStatusError(e);
    }
  }

  void sendNotify() {
    if (useUpdate) update(builderIDs);
    if (useChange) {
      change(NsgBaseControllerData(controller: this), status: currentStatus);
    }
  }

  FutureOr<bool> retryRequestIf(Exception exception) async {
    if (exception is NsgApiException) {
      if (exception.error.code == 401) {
        var provider =
            NsgDataClient.client.getNewObject(dataType).remoteProvider;
        await provider.connect(this);
        if (provider.isAnonymous) {
          //Ошибка авторизации - переход на логин

          await Get.to(provider.loginPage)!.then((value) => Get.back());
        }
      }
    }
    return true;
  }

  Future<List<NsgDataItem>> doRequestItems() async {
    var request = NsgDataRequest(dataItemType: dataType);
    return await request.requestItems(
        filter: getRequestFilter,
        loadReference: referenceList,
        autoRepeate: autoRepeate,
        autoRepeateCount: autoRepeateCount,
        retryIf: (e) => retryRequestIf(e));
  }

  ///is calling after new Items are putted in itemList
  void afterUpdate() {}

  ///is calling after new items are got from API before they are placed to ItemList
  void afterRequestItems(List<NsgDataItem> newItemsList) {}

  List<NsgDataItem> filter(List<NsgDataItem> newItemsList) {
    if (dataBinding == null) return newItemsList;
    if (masterController!.selectedItem == null ||
        !masterController!.selectedItem!.fieldList.fields
            .containsKey(dataBinding!.masterFieldName)) return newItemsList;
    var masterValue = masterController!
        .selectedItem!.fieldValues.fields[dataBinding!.masterFieldName!];

    var list = <NsgDataItem>[];
    newItemsList.forEach((element) {
      if (element.fieldValues.fields[dataBinding!.slaveFieldName!] ==
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

  NsgDataRequestParams? get getRequestFilter => null;

  FutureOr<void> _updateStatusError(Exception e) {
    currentStatus = RxStatus.error(e.toString());
    if (useUpdate) update(builderIDs);
    if (useChange) {
      change(null, status: currentStatus);
    }
  }

  void masterValueChanged(EventArgs? args) async {
    //if (!matchFilter(selectedItem)) selectedItem = null;
    await requestItems();
  }
}
