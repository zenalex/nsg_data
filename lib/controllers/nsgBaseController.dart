import 'dart:async';

import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:nsg_data/controllers/nsg_controller_filter.dart';
import 'package:nsg_data/nsg_comparison_operator.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
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
  NsgDataItem? backupItem;

  ///Флаг отложенной инициализации. Выставляется в true при создании контроллера,
  ///если свойство requestOnInit стоит false. Сбросится при первом вызове метода
  ///requestItems
  bool lateInit = false;

  ///Параметры сортировки данных
  ///Устанавляваются компонентами (например, таблицей), передаются в запрос через getRequestFilter
  String sorting = '';

  ///Функция для отображения ошибок пользователю
  ///Если не задана для конкретного контроллера, используется заданная по умолчанию NsgApiException.showExceptionDefault
  ///Последняя, задается в пакете nsg_controls
  void Function(NsgApiException)? showException;

  set selectedItem(NsgDataItem? newItem) {
    var itemChanged = _selectedItem != newItem;
    _selectedItem = newItem;
    if (itemChanged) {
      selectedItemChanged.broadcast(null);
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
    currentStatus = RxStatus.empty();
    sendNotify();
    super.onClose();
  }

  ///Request Items
  Future requestItems() async {
    lateInit = false;
    await _requestItems();
    sendNotify();
  }

  ///Обновление данных
  Future refreshData() async {
    currentStatus = RxStatus.loading();
    sendNotify();
    await requestItems();
    // currentStatus = RxStatus.success();
    // sendNotify();
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
        await afterRequestItems(newItemsList);
        if (useDataCache) dataCache = newItemsList;
      }
      dataItemList = filter(newItemsList);
      if (selectedItem != null && !dataItemList.contains(selectedItem)) selectedItem = null;
      if (selectedItem == null && autoSelectFirstItem && dataItemList.isNotEmpty) {
        selectedItem = dataItemList[0];
      }
      //service method for descendants
      await afterUpdate();
      // 20.06.2022 Зачем посылать refresh, если он будет отправлен позже в requestItems
      // sendNotify();
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
  Future afterUpdate() async {}

  ///is calling after new items are got from API before they are placed to ItemList
  Future afterRequestItems(List<NsgDataItem> newItemsList) async {}

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
    if (sorting.isNotEmpty) {
      param.sorting = sorting;
    }
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
    if (masterController != null && masterController!.selectedItem != null) {
      await refreshData();
    }
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
    if (needRefreshSelectedItem) {
      setAndRefreshSelectedItem(element, referenceList);
    } else {
      selectedItem = element;
    }

    Get.toNamed(pageName);
  }

  ///Close item page and restore current (selectedItem) item from backup
  void itemPageCancel() {
    if (backupItem != null) {
      selectedItem = backupItem;
      //20.06.2022 Попытка убрать лишнее обновление
      //selectedItemChanged.broadcast(null);
      backupItem = null;
    }
    Get.back();
  }

  ///Close item page and post current (selectedItem) item to databese (server)
  void itemPagePost() async {
    currentStatus = RxStatus.loading();
    sendNotify();
    try {
      await _postSelectedItem();
      if (backupItem != null && dataItemList.contains(backupItem)) {
        dataItemList.remove(backupItem!);
      }
      if (backupItem != null) {
        backupItem = null;
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
      currentStatus = RxStatus.success();
      sendNotify();
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

  ///Вызывается после метода refreshItem.
  ///Можно использовать, например, для обновления связанных контроллеров
  Future afterRefreshItem(NsgDataItem item, List<String>? referenceList) async {}

  ///Перечитать из базы данных текущий объект (selectedItem)
  ///На время чтерния статус контроллера будет loading
  ///referenceList - ссылки для дочитывания. Если передан null - будут дочитаны все
  ///Одно из применений, перечитывание объекта с целью чтения его табличных частей при переходе из формы списка в форму элемента
  Future setAndRefreshSelectedItem(NsgDataItem item, List<String>? referenceList) async {
    currentStatus = RxStatus.loading();
    sendNotify();

    var newItem = await refreshItem(item, referenceList);
    var index = dataItemList.indexOf(item);
    if (index >= 0) {
      dataItemList.replaceRange(index, index + 1, [newItem]);
    }
    //запоминаем текущий элемент в бэкапе на случай отмены редактирования пользователем для возможности вернуть
    //вернуть результат обратно
    //selectedItem = null;
    selectedItem = newItem.clone();
    backupItem = newItem;
    await afterRefreshItem(newItem, referenceList);
    currentStatus = RxStatus.success();
    sendNotify();
  }
}
