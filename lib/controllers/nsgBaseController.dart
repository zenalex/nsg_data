import 'dart:async';

import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:nsg_data/controllers/nsg_controller_filter.dart';
import 'package:nsg_data/nsg_comparison_operator.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
import 'package:retry/retry.dart';
import 'nsg_controller_filter.dart';

class NsgBaseController extends GetxController with StateMixin<NsgBaseControllerData> {
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

  ///Запрет редактирования данных пользователей
  bool readOnly;

  ///Разрешен переход в режим редактирования
  bool editModeAllowed;

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

  ///Флаг отложенной инициализации. Выставляется в true при создании контроллера,
  ///если свойство requestOnInit стоит false. Сбросится при первом вызове метода
  ///requestItems
  bool lateInit = false;

  ///Функция для отображения ошибок пользователю
  ///Если не задана для конкретного контроллера, используется заданная по умолчанию NsgApiException.showExceptionDefault
  ///Последняя, задается в пакете nsg_controls
  void Function(NsgApiException)? showException;

  set selectedItem(NsgDataItem? newItem) {
    //Убрал проверку на совпадение значений: т.к. это неправильно при обновлении (перечитывании) значения из БД
    //if (_selectedItem != newItem) {
    _selectedItem = newItem;
    selectedItemChanged.broadcast(null);
    sendNotify();
    //}
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
      this.retryIf,
      this.editModeAllowed = true,
      this.readOnly = true})
      : super() {
    onRetry ??= _updateStatusError;
  }

  @override
  void onInit() {
    //В случае задания связки мастер-деталь, формируем подписки
    //для автоматического обновлегния данных в slave контроллере,
    //при изменении selectedItem в master контроллере
    if (masterController != null) {
      masterController!.selectedItemChanged.subscribe(masterValueChanged);
    }
    if (dependsOnControllers != null) {
      dependsOnControllers!.forEach((element) {
        element.selectedItemChanged.subscribe(masterValueChanged);
      });
    }
    //Проверяем, есть ли у типа данных, зарегистрированных в контроллере
    //заданное имя поля для задания фильтра по периоду (periodFieldName)
    if (!NsgDataClient.client.isRegistered(dataType)) {
      controllerFilter.isPeriodAllowed = false;
    } else {
      var dataItem = NsgDataClient.client.getNewObject(dataType);
      if (dataItem.periodFieldName.isEmpty) {
        controllerFilter.isPeriodAllowed = false;
      } else {
        controllerFilter.isPeriodAllowed = true;
        controllerFilter.periodFieldName = dataItem.periodFieldName;
      }
    }

    if (requestOnInit)
      requestItems();
    else
      lateInit = true;
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
    change(null, status: RxStatus.empty());
    super.onClose();
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
    lateInit = false;
    if (autoRepeate) {
      final r = RetryOptions(maxAttempts: autoRepeateCount);
      await r.retry(() => _requestItems(), onRetry: _updateStatusError, retryIf: retryIf);
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
      if (masterController != null && selectedMasterRequired && masterController!.selectedItem == null) {
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
      if (selectedItem == null && autoSelectFirstItem && dataItemList.isNotEmpty) {
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
        var provider = NsgDataClient.client.getNewObject(dataType).remoteProvider;
        await provider.connect(this);
        if (provider.isAnonymous) {
          //Ошибка авторизации - переход на логин
          await Get.to(provider.loginPage)!.then((value) => Get.back());
        }
      }
    }
    if (retryIf != null) {
      return await retryIf!(exception);
    }
    return !status.isEmpty;
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
    if (masterController!.selectedItem == null || !masterController!.selectedItem!.fieldList.fields.containsKey(dataBinding!.masterFieldName))
      return newItemsList;
    var masterValue = masterController!.selectedItem!.fieldValues.fields[dataBinding!.masterFieldName];

    var list = <NsgDataItem>[];
    newItemsList.forEach((element) {
      if (element.fieldValues.fields[dataBinding!.slaveFieldName] == masterValue) {
        list.add(element);
      }
    });
    return _applyControllerFilter(list);
  }

  List<NsgDataItem> _applyControllerFilter(List<NsgDataItem> newItemsList) {
    if (!controllerFilter.isAllowed || !controllerFilter.isOpen || controllerFilter.searchString == '') return newItemsList;
    return newItemsList.where((element) {
      for (var fieldName in element.fieldList.fields.keys) {
        var field = element.getField(fieldName);
        var s = '';
        if (field is NsgDataReferenceField) {
          s = field.getReferent(element).toString();
        } else {
          s = element.getFieldValue(fieldName).toString();
        }
        if (s.toString().toUpperCase().contains(controllerFilter.searchString.toUpperCase())) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  bool matchFilter(NsgDataItem item) {
    var list = [item];
    return filter(list).isNotEmpty;
  }

  NsgDataRequestParams? get getRequestFilter {
    var cmp = NsgCompare();
    //Добавление условия на мастер-деталь
    if (masterController != null &&
        masterController!.selectedItem != null &&
        masterController!.selectedItem!.fieldList.fields.containsKey(dataBinding!.masterFieldName)) {
      var masterValue = masterController!.selectedItem!.fieldValues.fields[dataBinding!.masterFieldName];
      cmp.add(name: dataBinding!.slaveFieldName, value: masterValue);
    }
    //Учитываем пользовательский фильтр на дату
    if (controllerFilter.isPeriodAllowed && controllerFilter.periodFieldName.isNotEmpty) {
      cmp.add(name: controllerFilter.periodFieldName, value: controllerFilter.nsgPeriod.beginDate, comparisonOperator: NsgComparisonOperator.greaterOrEqual);
      cmp.add(name: controllerFilter.periodFieldName, value: controllerFilter.nsgPeriod.endDate, comparisonOperator: NsgComparisonOperator.less);
    }

    var param = NsgDataRequestParams();
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
    return obx(widget, onError: onError, onLoading: onLoading, onEmpty: onEmpty);
  }

  ///Post selected item to the server
  Future _postSelectedItem() async {
    if (selectedItem == null) {
      throw new Exception("No selected item to post");
    }
    if (selectedItem == null) return;
    await selectedItem!.post();

    sendNotify();
  }

  ///Open item page to view and edit data
  ///element saved in backupItem to have possibility revert changes
  ///needRefreshSelectedItem - Требуется ли перечитать текущий элемент из БД, например, для чтения табличных частей
  void itemPageOpen(NsgDataItem element, String pageName, {bool needRefreshSelectedItem = false, List<String>? referenceList}) {
    selectedItem = element;
    if (needRefreshSelectedItem) {
      refreshSelectedItem(referenceList);
    }

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
    change(null, status: RxStatus.loading());
    try {
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
    } catch (ex) {
      //если это NsgApiExceptuion, то отображаем ошибку пользователю
      if (ex is NsgApiException) {
        var func = showException ?? NsgApiException.showExceptionDefault;
        if (func != null) func(ex);
      }
      rethrow;
    } finally {
      change(null, status: RxStatus.success());
    }
  }

  ///Перечитать указанный объект из базы данных
  ///item - перечитываемый объект
  ///referenceList - ссылки для дочитывания. Если передан null - будут дочитаны все
  ///Одно из применений, перечитывание объекта с целью чтения его табличных частей при переходе из формы списка в форму элемента
  Future<NsgDataItem> refreshItem(NsgDataItem item, List<String>? referenceList) async {
    var cmp = NsgCompare();
    cmp.add(name: item.primaryKeyField, value: item.getFieldValue(item.primaryKeyField));
    var filterParam = NsgDataRequestParams(compare: cmp);
    var request = NsgDataRequest(dataItemType: dataType);
    var answer = await request.requestItem(
        filter: filterParam, loadReference: referenceList, autoRepeate: autoRepeate, autoRepeateCount: autoRepeateCount, retryIf: (e) => retryRequestIf(e));
    return answer;
  }

  ///Перечитать из базы данных текущий объект (selectedItem)
  ///На время чтерния статус контроллера будет loading
  ///referenceList - ссылки для дочитывания. Если передан null - будут дочитаны все
  ///Одно из применений, перечитывание объекта с целью чтения его табличных частей при переходе из формы списка в форму элемента
  Future refreshSelectedItem(List<String>? referenceList) async {
    if (selectedItem == null) return;
    change(null, status: RxStatus.loading());

    var newItem = await refreshItem(selectedItem!, referenceList);
    var index = dataItemList.indexOf(selectedItem!);
    if (index >= 0) {
      dataItemList.replaceRange(index, index + 1, [newItem]);
    }
    //запоминаем текущий элемент в бэкапе на случай отмены редактирования пользователем для возможности вернуть
    //вернуть результат обратно
    //selectedItem = null;
    selectedItem = newItem.clone();
    _backupItem = newItem;
    change(null, status: RxStatus.success());
  }
}
