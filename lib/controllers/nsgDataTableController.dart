// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nsg_data/nsg_data.dart';

///Контроллер объекта табличной части
///Не читает ничего из БД, работает с текущей строкой MasterController
///Обязательные параметры к заданию:
///masterController - контроллер основного объекта, строку табличной части которого редактируем
///tableFieldName - имя поля типа NsgDafaReferenceList объектов из masterController - ссылка на строки табличной части
class NsgDataTableController<T extends NsgDataItem> extends NsgDataController<T> {
  ///Имя поля ссылки на таблицу
  String tableFieldName;
  NsgDataTableController(
      {super.requestOnInit = false,
      super.useUpdate,
      super.useChange,
      super.builderIDs,
      super.dataBindign,
      super.autoRepeate = false,
      super.autoRepeateCount = 10,
      super.useDataCache = false,
      super.selectedMasterRequired = true,
      super.autoSelectFirstItem = false,
      super.dependsOnControllers,
      required super.masterController,
      required this.tableFieldName,
      super.controllerMode})
      : super();

  ///Создает новую строку.
  @override
  Future<T> doCreateNewItem() async {
    assert(masterController != null && masterController!.selectedItem != null);
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    var row = NsgDataClient.client.getNewObject(dataTable.dataItemType) as T;
    row.id = Guid.newGuid();
    row.state = NsgDataItemState.create;
    row.storageType = controllerMode.storageType;
    row.ownerId = masterController!.selectedItem!.id;
    //dataTable.addRow(row); // FIXME не работает создание нового элемента в табличном контроллере!
    return row;
  }

  ///Установить текущей переданную строку
  @override
  Future setAndRefreshSelectedItem(NsgDataItem item, List<String>? referenceList) async {
    selectedItem = item.clone();
    backupItem = item;
    await afterRefreshItem(item, referenceList);
    sendNotify();
  }

  ///Перечитать указанный объект из базы данных
  ///Так как данный объект является строкой таблицы, читать из БД ничего не нужно
  @override
  Future<NsgDataItem> refreshItem(NsgDataItem item, List<String>? referenceList, {bool changeStatus = false}) async {
    return item;
  }

  ///Close row page and post current (selectedItem) item to dataTable
  @override
  Future<bool> itemPagePost({bool goBack = true, bool useValidation = true}) async {
    assert(selectedItem != null);
    var validationResult = selectedItem!.validateFieldValues();
    if (!validationResult.isValid) {
      var err = NsgApiException(NsgApiError(code: 999, message: validationResult.errorMessageWithFields()));
      if (NsgApiException.showExceptionDefault != null) {
        NsgApiException.showExceptionDefault!(err);
      }
      sendNotify();
      return false;
    }
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    var oldIndex = dataTable.length;
    if (backupItem != null && dataItemList.contains(backupItem)) {
      oldIndex = dataItemList.indexOf(backupItem!);
      dataItemList.remove(backupItem!);
      dataTable.removeRow(backupItem!);
    }
    if (backupItem != null) {
      backupItem = null;
    }
    if (!dataItemList.contains(currentItem)) {
      //dataItemList.add(selectedItem!);
      dataTable.insertRow(oldIndex, currentItem);
      //items.add(currentItem);
    }
    selectedItem!.state = NsgDataItemState.fill;
    if (goBack) {
      Get.back();
    }
    if (masterController != null) {
      masterController!.sendNotify();
    }
    requestItems();
    return true;
  }

  ///Open row page to view and edit data
  @override
  void itemPageOpen(NsgDataItem element, String pageName, {bool needRefreshSelectedItem = false, List<String>? referenceList, bool offPage = false}) {
    if (backupItem == null) {
      selectedItem = element.clone();
      backupItem = element;
    } else {
      selectedItem = element;
    }
    selectedItem!.state = NsgDataItemState.fill;
    if (offPage) {
      Get.offAndToNamed(pageName);
    } else {
      NsgNavigator.instance.toPage(pageName);
    }
  }

  ///Close row page and restore current (selectedItem) item from backup
  @override
  Future<void> itemPageCancel({bool useValidation = true, BuildContext? context}) async {
    if (useValidation) {
      if (isModified) {
        if (NsgBaseController.saveOrCancelDefaultDialog == null) {
          return;
        }
        var result = await NsgBaseController.saveOrCancelDefaultDialog!(context ?? Get.context!);
        switch (result) {
          case null:
            break;
          case true:
            itemPagePost(goBack: true);
            break;
          case false:
            if (backupItem != null) {
              selectedItem = backupItem;
              //20.06.2022 Попытка убрать лишнее обновление
              //selectedItemChanged.broadcast(null);
              backupItem = null;
            }
            Get.back();
            break;
        }
      } else {
        if (backupItem != null) {
          selectedItem = backupItem;
          //20.06.2022 Попытка убрать лишнее обновление
          //selectedItemChanged.broadcast(null);
          backupItem = null;
        }
        Get.back();
      }
    }
  }

  @override
  NsgDataRequestParams get getRequestFilter {
    var param = NsgDataRequestParams();
    return param;
  }

  ///Request Items
  @override
  Future requestItems({List<NsgUpdateKey>? keys, NsgDataRequestParams? filter}) async {
    lateInit = false;
    if (masterController == null || masterController!.selectedItem == null) {
      return;
    }
    await filterData(filterParam: filter);
    sortDataItemList();
    currentStatus = GetStatus.success(NsgBaseController.emptyData);
    sendNotify(keys: keys);
  }

  ///Создает новый элемент и переходит на страницу элемента.
  ///pageName - страница для перехода и отображения/редактирования нового элемента
  @override
  Future<T> createNewItemAsync() async {
    assert(masterController != null && masterController!.selectedItem != null);
    //var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    currentItem = await doCreateNewItem();
    return currentItem;
  }

  ///Удаление текущего элемента
  ///если goBack == true (по умолчанию), после сохранения элемента, будет выполнен переход назад
  Future itemRemove({bool goBack = true}) async {
    assert(selectedItem != null, 'itemDelete');
    assert(masterController != null && masterController!.selectedItem != null, 'itemDelete');
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    dataTable.removeRow(currentItem);
    await filterData();
    selectedItem = null;
    backupItem = null;
    if (goBack) {
      Get.back();
    }
    if (masterController != null) {
      masterController!.sendNotify();
    }
    currentStatus = GetStatus.success(NsgBaseController.emptyData);
    if (!goBack) {
      sendNotify();
    }
  }

  ///Удаление массива строк из табличной части
  @override
  Future itemsRemove(List<NsgDataItem> itemsToRemove, {bool goBack = true}) async {
    assert(masterController != null && masterController!.selectedItem != null, 'itemDelete');
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    for (var element in itemsToRemove) {
      dataTable.removeRow(element);
    }
    await filterData();
    selectedItem = null;
    backupItem = null;
    if (masterController != null) {
      masterController!.sendNotify();
    }
    if (goBack) {
      Get.back();
    }
    currentStatus = GetStatus.success(NsgBaseController.emptyData);
    sendNotify();
  }

  ///Фильтрует строки из мастер и удовлетворяющие фильтру добавляет в контроллер
  Future filterData({NsgDataRequestParams? filterParam}) async {
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    var filter = filterParam ?? getRequestFilter;
    dataItemList = [];
    for (var row in dataTable.rows) {
      if (filter.compare.isValid(row)) {
        dataItemList.add(row);
      }
    }
  }
}
