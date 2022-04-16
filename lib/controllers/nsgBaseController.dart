import 'dart:async';

import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:nsg_data/controllers/nsg_controller_filter.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
import 'package:retry/retry.dart';
import 'nsg_controller_filter.dart';

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

  ///Фильтр. После изменения необходимо вызвать refreshData()
  final controllerFilter = NsgControllerFilter();

  /// If no [retryIf] function is given this will retry any for any [Exception]
  /// thrown. To retry on an [Error], the error must be caught and _rethrown_
  /// as an [Exception].
  FutureOr<bool> Function(Exception)? retryIf;

  /// At every retry the [onRetry] function will be called (if given). The
  /// function [fn] will be invoked at-most [this.attempts] times.
  FutureOr<void> Function(Exception)? onRetry;

  NsgDataItem? _selectedItem;
  NsgDataItem? get selectedItem => _selectedItem;

  ///Сохраненный эелемент для возможности возврата предыдущего значения
  ///например, в случае отмены редактирования
  NsgDataItem? _backupItem;

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

  ///Обновление данных
  Future refreshData() async {
    change(null, status: RxStatus.loading());
    await requestItems();
    change(null, status: RxStatus.success());
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
    if (dataBinding == null) return _applyControllerFilter(newItemsList);
    if (masterController!.selectedItem == null ||
        !masterController!.selectedItem!.fieldList.fields
            .containsKey(dataBinding!.masterFieldName)) return newItemsList;
    var masterValue = masterController!
        .selectedItem!.fieldValues.fields[dataBinding!.masterFieldName];

    var list = <NsgDataItem>[];
    newItemsList.forEach((element) {
      if (element.fieldValues.fields[dataBinding!.slaveFieldName] ==
          masterValue) {
        list.add(element);
      }
    });
    return _applyControllerFilter(list);
  }

  List<NsgDataItem> _applyControllerFilter(List<NsgDataItem> newItemsList) {
    if (!controllerFilter.isAllowed ||
        !controllerFilter.isOpen ||
        controllerFilter.searchString == '') return newItemsList;
    return newItemsList
        .where((element) =>
            element.toString().contains(controllerFilter.searchString))
        .toList();
  }

  bool matchFilter(NsgDataItem item) {
    var list = [item];
    return filter(list).isNotEmpty;
  }

  NsgDataRequestParams? get getRequestFilter {
    if (masterController == null ||
        masterController!.selectedItem == null ||
        !masterController!.selectedItem!.fieldList.fields
            .containsKey(dataBinding!.masterFieldName)) return null;

    var masterValue = masterController!
        .selectedItem!.fieldValues.fields[dataBinding!.masterFieldName];

    var param = NsgDataRequestParams();
    var cmp = NsgCompare();
    cmp.add(name: dataBinding!.slaveFieldName, value: masterValue);
    param.compare = cmp;

    return param;
  }

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

  Widget obxBase(
    Widget Function(NsgBaseControllerData?) widget, {
    Widget Function(String? error)? onError,
    Widget? onLoading,
    Widget? onEmpty,
  }) {
    return obx(widget,
        onError: onError, onLoading: onLoading, onEmpty: onEmpty);
  }

  ///Post selected item to the server
  Future _postSelectedItem() async {
    if (selectedItem == null) {
      throw new Exception("No selected item to post");
    }
    await selectedItem!.post();

    sendNotify();
  }

  ///Open item page to view and edit data
  ///element saved in backupItem to have possibility revert changes
  void itemPageOpen(NsgDataItem element, String pageName) {
    selectedItem = null;
    selectedItem = element.clone();
    _backupItem = element;
    Get.toNamed(pageName);
  }

  ///Close item page and restore current (selectedItem) item from backup
  void itemPageCancel() {
    if (_backupItem != null) {
      selectedItem = null;
      selectedItem = _backupItem;
      _backupItem = null;
    }
    Get.back();
  }

  ///Close item page and post current (selectedItem) item to databese (server)
  void itemPagePost() async {
    await _postSelectedItem();
    if (_backupItem != null && dataItemList.contains(_backupItem)) {
      dataItemList.remove(_backupItem!);
    }
    if (_backupItem != null) {
      _backupItem = null;
    }
    if (!dataItemList.contains(selectedItem)) {
      dataItemList.add(selectedItem!);
    }
    Get.back();
  }
}
