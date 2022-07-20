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
      {super.requestOnInit,
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
      required this.tableFieldName})
      : super();

  ///Создает новую строку.
  @override
  Future<T> doCreateNewItem() async {
    assert(masterController != null && masterController!.selectedItem != null);
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    var row = NsgDataClient.client.getNewObject(dataTable.dataItemType) as T;
    dataTable.addRow(row);
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
  Future<NsgDataItem> refreshItem(NsgDataItem item, List<String>? referenceList) async {
    return item;
  }

  ///Close row page and post current (selectedItem) item to dataTable
  @override
  Future itemPagePost({bool goBack = true}) async {
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
    if (masterController != null) {
      masterController!.sendNotify();
    }
    sendNotify();
  }

  ///Open row page to view and edit data
  @override
  void itemPageOpen(NsgDataItem element, String pageName, {bool needRefreshSelectedItem = false, List<String>? referenceList}) {
    selectedItem = element;
    Get.toNamed(pageName);
  }

  ///Close row page and restore current (selectedItem) item from backup
  @override
  void itemPageCancel() {
    if (backupItem != null) {
      selectedItem = backupItem;
      backupItem = null;
    }
    Get.back();
  }

  @override
  NsgDataRequestParams? get getRequestFilter {
    var param = NsgDataRequestParams();
    return param;
  }

  ///Request Items
  @override
  Future requestItems() async {
    lateInit = false;
    if (masterController == null || masterController!.selectedItem == null) return;
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    dataItemList = dataTable.rows;
    currentStatus = RxStatus.success();
    sendNotify();
  }

  ///Создает новый элемент и переходит на страницу элемента.
  ///pageName - страница для перехода и отображения/редактирования нового элемента
  void createNewItem(String pageName) {
    assert(masterController != null && masterController!.selectedItem != null);
    var dataTable = NsgDataTable(owner: masterController!.selectedItem!, fieldName: tableFieldName);
    currentItem = NsgDataClient.client.getNewObject(dataTable.dataItemType) as T;
    dataTable.addRow(currentItem);
    dataItemList = dataTable.rows;
    Get.toNamed(pageName);
  }
}
