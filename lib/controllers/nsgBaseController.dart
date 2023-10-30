// ignore_for_file: file_names

import 'dart:async';

import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:nsg_controls/widgets/nsg_dialog_save_or_cancel.dart';
import 'package:nsg_data/controllers/nsg_controller_filter.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:get/get.dart';
import 'package:nsg_data/nsg_data_delete.dart';
import 'nsg_controller_regime.dart';

class NsgBaseController extends GetxController with StateMixin<NsgBaseControllerData> {
  Type dataType;
  bool requestOnInit;
  bool selectedMasterRequired;
  bool useDataCache;
  bool autoSelectFirstItem;

  ///Map полей с ошибками - имя поля - текст ошибки
  Map<String, String> fieldsWithError = {};

  List<NsgDataItem> dataItemList = <NsgDataItem>[];
  List<NsgDataItem> dataCache = <NsgDataItem>[];

  //Referenses to load
  List<String>? referenceList;
  final selectedItemChanged = Event<EventArgs>();
  //Запрошено обновление данных
  final itemsRequested = Event<EventArgs>();
  //Смерился статус контроллера
  final statusChanged = Event<EventArgs>();

  ///Use update method on data update
  bool useUpdate;

  ///Use change method on data update
  bool useChange;

  ///Master controller. Using for binding.
  NsgBaseController? masterController;
  List<NsgBaseController>? dependsOnControllers;

  ///Binding rule
  NsgDataBinding? dataBinding;

  NsgDataControllerMode controllerMode = NsgDataControllerMode.defaultDataControllerMode;

  GetStatus<NsgBaseControllerData> _currentStatus = GetStatus.loading();

  //Переменные, отвечающие за очередь сохранения данных
  //Слишком частое сохранение может приводить к ошибкам и создавать излишнюю нагрузку на сервер
  //Также, это дает возможность выделения в будущем подобных процессов в отдельный поток
  ///Очередь элементов, отправленных на сохранение
  final List<NsgDataItem> _postQueue = [];

  ///Списох элементов, отправленных на сервер
  final List<NsgDataItem> _postingItems = [];

  ///Флажок активности сохранения данных через очередь
  bool _isPosting = false;

  ///Status of last data request operation
  GetStatus<NsgBaseControllerData> get currentStatus {
    if (_currentStatus.isSuccess) {
      if (masterController != null && !masterController!.currentStatus.isSuccess) {
        return masterController!.currentStatus;
      }
    }
    return _currentStatus;
  }

  set currentStatus(GetStatus<NsgBaseControllerData> value) => _currentStatus = value;

  ///Enable auto repeate attempts of requesting data
  bool autoRepeate;

  ///Set count of attempts of requesting data
  int autoRepeateCount;

  ///Фильтр. После изменения необходимо вызвать controllerFilter.refreshControllerWithDelay()
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
  NsgSorting sorting = NsgSorting();

  ///Функция для отображения ошибок пользователю
  ///Если не задана для конкретного контроллера, используется заданная по умолчанию NsgApiException.showExceptionDefault
  ///Последняя, задается в пакете nsg_controls
  void Function(NsgApiException)? showException;

  ///Определяет текущий режим работы контроллера
  var regime = NsgControllerRegime.view;

  ///Сколько всего элементов, удовлетворяющим условиям поиска, хранится на сервере
  ///Если значение null, значит не было успешного запроса к серверу, либо, сервер не вернул общее количество элементов
  int? totalCount;

  ///Номер элемента, начиная с которого возвращать данные
  ///Используется для пейджинга
  int? top;

  ///Событие о выборе значения пользователем. Срабатывает в режиме selection при выборе пользователем элемента в форме списка
  void Function(NsgDataItem)? onSelected;

  ///Контроллер настроек пользователя. Если задан, используется для хранения и извлечения информации
  ///об избранных элементах и последних используемых
  NsgUserSettingsController? userSettingsController;

  List<NsgUpdateKey> updateKeys = [];

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
      this.useUpdate = true,
      this.useChange = true,
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
      this.readOnly = true,
      NsgDataControllerMode? controllerMode})
      : super() {
    onRetry ??= _updateStatusError;
    this.controllerMode = controllerMode ?? NsgDataControllerMode.defaultDataControllerMode;
  }

  @override
  void onInit() {
    //В случае задания связки мастер-деталь, формируем подписки
    //для автоматического обновлегния данных в slave контроллере,
    //при изменении selectedItem в master контроллере
    if (masterController != null) {
      masterController!.selectedItemChanged.subscribe(masterValueChanged);
      masterController!.itemsRequested.subscribe(masterItemsRequested);
    }
    if (dependsOnControllers != null) {
      for (var element in dependsOnControllers!) {
        element.selectedItemChanged.subscribe(masterValueChanged);
      }
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

    controllerFilter.controller = this;
    userSettingsController ??= NsgUserSettings.controller;

    if (requestOnInit) {
      requestItems();
    } else {
      lateInit = true;
    }

    super.onInit();
  }

  @override
  void onClose() {
    if (masterController != null) {
      masterController!.selectedItemChanged.unsubscribe(masterValueChanged);
      masterController!.itemsRequested.unsubscribe(masterItemsRequested);
    }
    if (dependsOnControllers != null) {
      for (var element in dependsOnControllers!) {
        element.selectedItemChanged.unsubscribe(masterValueChanged);
      }
    }
    currentStatus = GetStatus.empty();
    super.onClose();
  }

  saveBackup(NsgDataItem item) {
    selectedItem = item.clone();
    backupItem = item;
  }

  ///Request Items
  Future requestItems({List<NsgUpdateKey>? keys, NsgDataRequestParams? filter}) async {
    lateInit = false;
    itemsRequested.broadcast();
    await _requestItems(filter: filter);
    await getFavorites();
    itemsRequested.broadcast();
    sendNotify(keys: keys);
  }

  ///Обновление данных
  Future refreshData({List<NsgUpdateKey>? keys, NsgDataRequestParams? filter}) async {
    currentStatus = GetStatus.loading();
    sendNotify(keys: keys);
    await requestItems(keys: keys, filter: filter);
  }

  Future _requestItems({NsgDataRequestParams? filter}) async {
    try {
      if (masterController != null && selectedMasterRequired && masterController!.selectedItem == null) {
        if (dataItemList.isNotEmpty) {
          dataItemList.clear();
        }
        return;
      }
      List<NsgDataItem> newItemsList;
      if (useDataCache && dataCache.isNotEmpty) {
        newItemsList = _filter(dataCache);
        currentStatus = GetStatus.success(emptyData);
      } else {
        newItemsList = await doRequestItems(filter: filter);

        //service method for descendants
        currentStatus = GetStatus.success(emptyData);
        await afterRequestItems(newItemsList);
        if (useDataCache) dataCache = newItemsList;
      }
      //Вызывать локальную фильтрацию имеет смысл не имеет смысла при запросе частичных данных с сервера
      //Возможно, при загрузке всех данных, имеет смысл активировать локальный поиск вместо серврного, но врядли одновременно
      dataItemList = newItemsList;
      //dataItemList = filter(newItemsList);
      // if (selectedItem != null && dataItemList.firstWhereOrNull((e) => e.id == selectedItem!.id) == null) selectedItem = null; // FIXME вернуть обратно
      //if (selectedItem == null && autoSelectFirstItem && dataItemList.isNotEmpty) { // FIXME вернуть обратно
      if (autoSelectFirstItem && dataItemList.isNotEmpty) {
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

  ///Отправить сообщение о необходимоси обновления
  ///Если передан список ключей, то обновление будет дано только для них
  void sendNotify({List<NsgUpdateKey>? keys}) {
    if (useUpdate) {
      if (keys != null) {
        update(keys);
      } else {
        update(_registeredUpdateKeys.keys.toList());
      }
      update(keys ?? updateKeys);
    }
    if (useChange && keys == null) {
      //Если статус не изменился, refresh вызван не будет. Чтобы избежать этого, вызываем refresh вручную
      var needRefresh = currentStatus == status;
      change(currentStatus);
      if (needRefresh) {
        refresh();
      }
    }
    statusChanged.broadcast(null);
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
      if (exception.error.code == 400) {
        return false;
      }
    }
    if (retryIf != null) {
      return await retryIf!(exception);
    }
    return !status.isEmpty;
  }

  Future<List<NsgDataItem>> doRequestItems({NsgDataRequestParams? filter}) async {
    var request = NsgDataRequest(dataItemType: dataType, storageType: controllerMode.storageType);
    var newItems = await request.requestItems(
        filter: filter ?? getRequestFilter,
        loadReference: referenceList,
        autoRepeate: autoRepeate,
        autoRepeateCount: autoRepeateCount,
        userRetryIf: (e) => retryRequestIf(e));
    totalCount = request.totalCount;
    return newItems;
  }

  ///is calling after new Items are putted in itemList
  Future afterUpdate() async {}

  ///is calling after new items are got from API before they are placed to ItemList
  Future afterRequestItems(List<NsgDataItem> newItemsList) async {}

  List<NsgDataItem> _filter(List<NsgDataItem> newItemsList) {
    if (dataBinding == null) return _applyControllerFilter(newItemsList);
    if (masterController!.selectedItem == null || !masterController!.selectedItem!.fieldList.fields.containsKey(dataBinding!.masterFieldName)) {
      return newItemsList;
    }
    var masterValue = masterController!.selectedItem!.fieldValues.fields[dataBinding!.masterFieldName];

    var list = <NsgDataItem>[];
    for (var element in newItemsList) {
      if (element.fieldValues.fields[dataBinding!.slaveFieldName] == masterValue) {
        list.add(element);
      }
    }
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

  ///Проверяем, удовлетворяет ли заданный элемент фильтру контроллера
  bool matchFilter(NsgDataItem item) {
    var list = [item];
    return _filter(list).isNotEmpty;
  }

  ///Фильтрует строки из по фильтру добавляет в контроллер
  ///Если фильтр не задан, он будет запрошен у контроллера стандартным способом - через getRequestFilter
  ///Возвращает отфильтрованные и отсортированные данные
  Future<List<NsgDataItem>> filterItems({required List<NsgDataItem> newItemsList, NsgDataRequestParams? filterParam}) async {
    var filter = filterParam ?? getRequestFilter;
    var filteredItemList = <NsgDataItem>[];
    for (var row in newItemsList) {
      if (filter.compare.isValid(row)) {
        filteredItemList.add(row);
      }
    }
    sortDataItemList(newItemsList: filteredItemList);
    return filteredItemList;
  }

  NsgDataRequestParams get getRequestFilter {
    var cmp = NsgCompare();
    //Добавление условия на мастер-деталь
    if (masterController != null &&
        masterController!.selectedItem != null &&
        masterController!.selectedItem!.fieldList.fields.containsKey(dataBinding!.masterFieldName)) {
      var masterValue = masterController!.selectedItem!.fieldValues.fields[dataBinding!.masterFieldName];
      cmp.add(name: dataBinding!.slaveFieldName, value: masterValue);
    }
    //Учитываем пользовательский фильтр на дату
    if (controllerFilter.isOpen && controllerFilter.isPeriodAllowed && controllerFilter.periodFieldName.isNotEmpty) {
      cmp.add(name: controllerFilter.periodFieldName, value: controllerFilter.nsgPeriod.beginDate, comparisonOperator: NsgComparisonOperator.greaterOrEqual);
      cmp.add(name: controllerFilter.periodFieldName, value: controllerFilter.nsgPeriod.endDate, comparisonOperator: NsgComparisonOperator.less);
    }
    //Добавляем условие по строке поиска если фильтр разрешен и открыт
    if (controllerFilter.isOpen && controllerFilter.isAllowed && controllerFilter.searchString.isNotEmpty) {
      var dataItem = NsgDataClient.client.getNewObject(dataType);
      var fieldNames = dataItem.searchFieldList;

      if (fieldNames.isNotEmpty) {
        var searchCmp = NsgCompare();
        searchCmp.logicalOperator = NsgLogicalOperator.or;
        for (var fieldName in fieldNames) {
          var field = dataItem.fieldList.fields[fieldName];
          if ((field is NsgDataStringField || field is NsgDataReferenceField) && field is! NsgDataEnumReferenceField) {
            searchCmp.add(name: fieldName, value: controllerFilter.searchString, comparisonOperator: NsgComparisonOperator.containWords);
          }
        }
        cmp.add(name: "SearchStringComparison", value: searchCmp);
      }
    }

    var param = NsgDataRequestParams();
    param.top = top ?? 0;
    param.replaceCompare(cmp);
    if (sorting.isNotEmpty) {
      param.sorting = sorting.toString();
    }
    return param;
  }

  FutureOr<void> _updateStatusError(Exception e) {
    currentStatus = GetStatus.error(e.toString());
    sendNotify();
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

  static Widget Function() getDefaultProgressIndicator = _defaultProgressIndicator;
  static Widget _defaultProgressIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget obx(NotifierBuilder<NsgBaseControllerData?> widget,
      {Widget Function(String? error)? onError, Widget? onLoading, Widget? onEmpty, bool hideProgress = false}) {
    return Observer(builder: (_) {
      if (status.isLoading) {
        return onLoading ?? (hideProgress ? widget(value) : getDefaultProgressIndicator());
      } else if (status.isError) {
        return onError != null ? onError(status.errorMessage) : Center(child: Text('A error occurred: ${status.errorMessage}'));
      } else if (status.isEmpty) {
        return onEmpty ?? const SizedBox.shrink();
      }
      return widget(value);
    });
  }

  ///Post selected item to the server
  Future _postSelectedItem() async {
    assert(selectedItem != null, 'No selected item to post');
    selectedItem!.storageType = controllerMode.storageType;
    await selectedItem!.post();

    //sendNotify();
  }

  ///Open item page to view and edit data
  ///element saved in backupItem to have possibility revert changes
  ///needRefreshSelectedItem - Требуется ли перечитать текущий элемент из БД, например, для чтения табличных частей
  void itemPageOpen(NsgDataItem element, String pageName, {bool needRefreshSelectedItem = false, List<String>? referenceList, bool offPage = false}) {
    assert(element.runtimeType == dataType, 'Использован неправильный контроллер для данного типа данных. ${element.runtimeType} != $dataType');
    if (needRefreshSelectedItem) {
      setAndRefreshSelectedItem(element, referenceList);
    } else {
      selectedItem = element.clone();
      backupItem = element;
    }

    if (offPage) {
      Get.offAndToNamed(pageName);
    } else {
      NsgNavigator.push(pageName);
    }
  }

  ///Создает новый элемент. Вызывается из createNewItem
  ///Может быть перекрыт для организации бизнес-логики запросов, например, заполнения нового элемента на сервере
  ///или проверки возможности создания нового элемента
  Future<NsgDataItem> doCreateNewItem() async {
    var elem = NsgDataClient.client.getNewObject(dataType);
    //Если выставлен признак создавать на сервере, создаем запрос на сервер
    if (elem.createOnServer) {
      var request = NsgDataRequest(dataItemType: dataType);
      elem = await request.requestItem(method: 'POST', function: elem.apiRequestItems + '/Create');
    } else {
      elem.newRecordFill();
    }
    elem.state = NsgDataItemState.create;
    elem.docState = NsgDataItemDocState.created;
    elem.storageType = controllerMode.storageType;
    return elem;
  }

  ///Create new item and open page to view and edit it
  ///pageName -  страница, которую необходимо открыть по окончанию создания нового элемента
  void newItemPageOpen({required String pageName, bool offPage = false}) {
    createAndSetSelectedItem();
    if (offPage) {
      Get.offAndToNamed(pageName);
    } else {
      NsgNavigator.instance.toPage(pageName);
    }
  }

  ///Создает новый элемент БД и устанавливает его в текущее selectedItem (currentItem)
  ///На время чтерния статус контроллера будет loading
  Future createAndSetSelectedItem() async {
    currentStatus = GetStatus.loading();
    sendNotify();
    itemsRequested.broadcast();
    try {
      var newItem = await doCreateNewItem();
      //запоминаем текущий элемент в бэкапе на случай отмены редактирования пользователем для возможности
      //сравнить были ли сделаны какие-либо изменения пользователем
      selectedItem = newItem.clone();
      backupItem = newItem;
      await afterRefreshItem(selectedItem!, referenceList);
      currentStatus = GetStatus.success(NsgBaseController.emptyData);
      sendNotify();
      selectedItemChanged.broadcast(null);
    } on Exception catch (e) {
      _updateStatusError(e);
    }
  }

  ///Copy item and open item page to view and edit data
  ///element saved in backupItem to have possibility revert changes
  ///referenceList - список полей для дочитывания. null - перечитать все
  void itemCopyPageOpen(NsgDataItem element, String pageName, {bool needRefreshSelectedItem = false, List<String>? referenceList}) {
    assert(element.runtimeType == dataType, 'Использован неправильный контроллер для данного типа данных. ${element.runtimeType} != $dataType');
    copyAndSetItem(element, needRefreshSelectedItem: needRefreshSelectedItem, referenceList: referenceList);
    NsgNavigator.instance.toPage(pageName);
  }

  ///Close item page and restore current (selectedItem) item from backup
  void itemPageCancel({bool useValidation = true}) async {
    if (useValidation) {
      if (isModified) {
        var result = await NsgDialogSaveOrCancel.saveOrCancel();
        switch (result) {
          case null:
            break;
          case true:
            itemPagePost(goBack: true);
            return;
          case false:
            break;
        }
      }
    }
    if (backupItem != null) {
      selectedItem = backupItem;
      //20.06.2022 Попытка убрать лишнее обновление
      //selectedItemChanged.broadcast(null);
      backupItem = null;
    }
    Get.back();
  }

  ///Close item page and post current (selectedItem) item to databese (server)
  ///если goBack == true (по умолчанию), после сохранения элемента, будет выполнен переход назад
  ///useValidation == true перед сохранением проводится валидация
  ///В случае успешного сохранения возвращает true
  Future<bool> itemPagePost({bool goBack = true, bool useValidation = true}) async {
    assert(selectedItem != null);
    if (useValidation) {
      var validationResult = selectedItem!.validateFieldValues();
      if (!validationResult.isValid) {
        var err = NsgApiException(NsgApiError(code: 999, message: validationResult.errorMessageWithFields()));
        if (NsgApiException.showExceptionDefault != null) {
          NsgApiException.showExceptionDefault!(err);
        }
        sendNotify();
        return false;
      }
    }

    currentStatus = GetStatus.loading();
    sendNotify();
    try {
      await _postSelectedItem();
      var oldIndex = dataItemList.length;
      if (backupItem != null && dataItemList.contains(backupItem)) {
        oldIndex = dataItemList.indexOf(backupItem!);
        dataItemList.remove(backupItem!);
      }
      if (backupItem != null) {
        backupItem = null;
      }
      if (!dataItemList.contains(selectedItem)) {
        dataItemList.insert(oldIndex, selectedItem!);
        sortDataItemList();
      }
      if (goBack) {
        Get.back();
      } else {
        saveBackup(selectedItem!);
      }
      if (masterController != null) {
        masterController!.sendNotify();
      }
    } catch (ex) {
      //если это NsgApiExceptuion, то отображаем ошибку пользователю
      if (ex is NsgApiException) {
        var func = showException ?? NsgApiException.showExceptionDefault;
        if (func != null) func(ex);
      }
      rethrow;
    } finally {
      currentStatus = GetStatus.success(NsgBaseController.emptyData);
      sendNotify();
      selectedItemChanged.broadcast(null);
    }
    return true;
  }

  ///Возвращает была ли модифицирована текущая строка контроллера после открытии страницы на редактирование
  ///По сути, сравнивает selectedItem и backupItem
  bool get isModified {
    if (backupItem == null || selectedItem == null) {
      return false;
    }

    return !selectedItem!.isEqual(backupItem!);
  }

  static Future<bool?> Function()? saveOrCancelDefaultDialog;

  ///Проверить были ли изменения в объекте, если нет, выполняем Back, если были, то спрашиваем пользователя сохранить изменения или отменить,
  ///а затем выполняем Back
  Future itemPageCloseCheck() async {
    if (selectedItem == null) return;
    if (!isModified || saveOrCancelDefaultDialog == null) {
      itemPageCancel();
      return;
    }
    bool? res = await saveOrCancelDefaultDialog!();
    if (res == null) {
    } else {
      if (res) {
        await itemPagePost();
      } else {
        itemPageCancel(useValidation: false);
      }
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
    var request = NsgDataRequest(dataItemType: dataType, storageType: controllerMode.storageType);
    var answer = await request.requestItem(
        filter: filterParam, loadReference: referenceList, autoRepeate: autoRepeate, autoRepeateCount: autoRepeateCount, retryIf: (e) => retryRequestIf(e));

    return answer;
  }

  Future<NsgDataItem> refreshCurrentItem({List<String>? referenceList}) async {
    if (selectedItem == null) {
      return NsgDataClient.client.getNewObject(dataType);
    }
    currentStatus = GetStatus.loading();
    sendNotify();
    selectedItem = await refreshItem(selectedItem!, referenceList);
    currentStatus = GetStatus.success(NsgBaseController.emptyData);
    sendNotify();
    return selectedItem!;
  }

  ///Вызывается после метода refreshItem.
  ///Можно использовать, например, для обновления связанных контроллеров
  Future afterRefreshItem(NsgDataItem item, List<String>? referenceList) async {}

  ///Перечитать из базы данных текущий объект (selectedItem)
  ///На время чтерния статус контроллера будет loading
  ///referenceList - ссылки для дочитывания. Если передан null - будут дочитаны все
  ///Одно из применений, перечитывание объекта с целью чтения его табличных частей при переходе из формы списка в форму элемента
  Future setAndRefreshSelectedItem(NsgDataItem item, List<String>? referenceList) async {
    assert(item.isNotEmpty, 'Попытка перечитать с сервера объект с пустым guid (например, новый)');
    selectedItem = item;
    currentStatus = GetStatus.loading();
    //11.02.2023 Зенков. Заменил на refresh, потому что иногда происходил конфликт обновления в процессе перерисовки
    //Например, TaskTuner, открытие задачи на просмотр
    refresh();
    //sendNotify();
    itemsRequested.broadcast();
    try {
      var newItem = await refreshItem(item, referenceList);
      var index = dataItemList.indexOf(item);
      if (index >= 0) {
        dataItemList.replaceRange(index, index + 1, [newItem]);
      } else if (newItem.isEmpty) {
        currentStatus = GetStatus.error('Ошибка NBC-509. Данный объект более недоступен');
        sendNotify();
        throw Exception('Ошибка NBC-509. Данный объект более недоступен');
      }
      //запоминаем текущий элемент в бэкапе на случай отмены редактирования пользователем для возможности вернуть
      //вернуть результат обратно
      //selectedItem = null;
      selectedItem!.copyFieldValues(newItem);
      backupItem = newItem;
      await afterRefreshItem(selectedItem!, referenceList);
      currentStatus = GetStatus.success(NsgBaseController.emptyData);
      sendNotify();
      selectedItemChanged.broadcast(null);
    } on Exception catch (e) {
      _updateStatusError(e);
    }
  }

  ///Перечитать из базы данных item, создать его копию
  ///На время чтерния статус контроллера будет loading
  ///referenceList - ссылки для дочитывания. Если передан null - будут дочитаны все
  ///Одно из применений, перечитывание объекта с целью чтения его табличных частей при переходе из формы списка в форму элемента
  Future copyAndSetItem(NsgDataItem item, {bool needRefreshSelectedItem = false, List<String>? referenceList}) async {
    assert(item.isNotEmpty, 'Попытка перечитать с сервера объект с пустым guid (например, новый)');
    currentStatus = GetStatus.loading();
    sendNotify();
    itemsRequested.broadcast();
    try {
      var newItem = needRefreshSelectedItem ? await refreshItem(item, referenceList) : item;
      var index = dataItemList.indexOf(item);
      if (index >= 0) {
        dataItemList.replaceRange(index, index + 1, [newItem]);
      } else if (newItem.isEmpty) {
        currentStatus = GetStatus.error('Ошибка NBC-509. Данный объект более недоступен');
        sendNotify();
        throw Exception('Ошибка NBC-509. Данный объект более недоступен');
      }
      selectedItem = newItem.clone(cloneAsCopy: true);
      backupItem = selectedItem!.clone();
      await afterRefreshItem(selectedItem!, referenceList);
      currentStatus = GetStatus.success(NsgBaseController.emptyData);
      sendNotify();
      selectedItemChanged.broadcast(null);
    } on Exception catch (e) {
      _updateStatusError(e);
    }
  }

  ///Сортирует данные в массиве элементов, если массив н передан, сортирует данные в массиве самого контроллера
  void sortDataItemList({List<NsgDataItem>? newItemsList}) {
    if (sorting.isEmpty) return;
    var sortingData = newItemsList ?? dataItemList;
    sortingData.sort(((a, b) {
      for (var param in sorting.paramList) {
        var fieldA = a.getField(param.parameterName);
        //var fieldB = b.getField(param.parameterName);
        int result = fieldA.compareTo(a, b);
        if (result == 0) continue;
        if (param.direction == NsgSortingDirection.ascending) return result;
        return result == 1 ? -1 : 1;
      }
      return 0;
    }));
  }

  ///Удаление текущего элемента
  ///если goBack == true (по умолчанию), после сохранения элемента, будет выполнен переход назад
  // Future itemRemove({bool goBack = true}) async {
  // assert(selectedItem != null, 'itemDelete');
  // if (dataItemList.contains(selectedItem)) {
  //   dataItemList.remove(selectedItem!);
  //   sortDataItemList();
  // }
  // selectedItem = null;
  // backupItem = null;
  // if (goBack) {
  //   Get.back();
  // }
  // if (masterController != null) {
  //   masterController!.sendNotify();
  // }
  // currentStatus = RxStatus.success();
  // sendNotify();
//}

  ///Удаление массива строк из табличной части
  ///На данный момент, метод реализован только для контроллера табличной части
  Future itemsRemove(List<NsgDataItem> itemsToRemove) async {
    await deleteItems(itemsToRemove);
  }

  void masterItemsRequested(EventArgs? args) {
    sendNotify();
  }

  NsgUpdateKey getUpdateKey(String id, NsgUpdateKeyType type) {
    var key = updateKeys.firstWhereOrNull((element) => element.id == id);
    if (key != null) return key;
    key = NsgUpdateKey(id: id, type: type);
    updateKeys.add(key);
    return key;
  }

  //Блок для работы с ключами обновления
  //Используется для частичного обновления страниц
  final Map<NsgUpdateKey, int> _registeredUpdateKeys = {};
  void registerUpdateKey(NsgUpdateKey updateKey) {
    var count = _registeredUpdateKeys[updateKey] ?? 0;
    _registeredUpdateKeys[updateKey] = count + 1;
  }

  void unregisterUpdateKey(NsgUpdateKey updateKey) {
    var count = _registeredUpdateKeys[updateKey] ?? 0;
    if (count > 0) {
      count--;
      if (count == 0) {
        _registeredUpdateKeys.remove(updateKey);
      } else {
        _registeredUpdateKeys[updateKey] = count;
      }
    }
  }

  Future postItems(List<NsgDataItem> itemsToPost, {bool showProgress = false}) async {
    if (controllerMode.storageType == NsgDataStorageType.server) {
      var p = NsgDataPost(dataItemType: dataType);
      p.itemsToPost = itemsToPost;
      var newItems = await p.postItems(loadReference: NsgDataRequest.addAllReferences(dataType));
      for (var item in newItems) {
        var old = itemsToPost.firstWhereOrNull((e) => e.id == item.id);
        if (old != null) {
          old.copyFieldValues(item);
          old.state = NsgDataItemState.fill;
        }
        old = dataItemList.firstWhereOrNull((e) => e.id == item.id);
        if (old != null) {
          old.copyFieldValues(item);
          old.state = NsgDataItemState.fill;
        }
      }
    } else {
      await NsgLocalDb.instance.postItems(itemsToPost);
    }
  }

  /// Удаляет currentItem в БД и в items
  Future deleteItem({bool goBack = true}) async {
    assert(selectedItem != null, 'При выполнении deleteItem() -> currentItem==null');
    await deleteItems([selectedItem!]);
    if (goBack) {
      NsgNavigator.instance.back();
    }
  }

  /// Удаляет выбранные элементы в БД и в items
  Future deleteItems(List<NsgDataItem> itemsToDelete) async {
    if (controllerMode.storageType == NsgDataStorageType.server) {
      if (itemsToDelete.isEmpty) return;
      var p = NsgDataDelete(dataItemType: itemsToDelete[0].runtimeType, itemsToDelete: itemsToDelete);
      await p.deleteItems();
    } else {
      await NsgLocalDb.instance.deleteItems(itemsToDelete);
    }
    var deleteList = [];
    deleteList.addAll(itemsToDelete);
    for (var item in deleteList) {
      if (dataItemList.contains(item)) {
        dataItemList.remove(item);
      }
    }
    sendNotify();
  }

  ///Метод, вызываемый при инициализации provider (загрузка приложения)
  Future loadProviderData() async {}

  List<String> get objectFieldsNames => NsgDataClient.client.getFieldList(dataType).fields.keys.toList();

  ///Поставить в очередь на сохранение, чтобы избезать параллельного сохранения
  ///Уменьшив таким образом нагрузку на сервер и избежать коллизий
  Future postItemQueue(NsgDataItem obj) async {
    if (_postQueue.contains(obj)) {
      return;
    }
    _postQueue.add(obj);
    if (_isPosting) {
      return;
    }
    _postingItemQueue();
  }

  int _errorsPostQueue = 0;
  Future _postingItemQueue() async {
    if (_isPosting) {
      return true;
    }
    if (_postQueue.isEmpty && _postingItems.isEmpty) {
      _isPosting = false;
      return;
    }
    _isPosting = true;
    var error = false;
    try {
      //Переносим массив сохраняемых элементов в отдельный список
      _postingItems.addAll(_postQueue);
      //Очищаем очередь, чтобы избежать повторного сохранения
      _postQueue.clear();
      //Непосредственно сохранение
      await postItems(_postingItems);
      _postingItems.clear();
    } catch (e) {
      error = true;
    } finally {
      _isPosting = false;
    }
    if (error) {
      _errorsPostQueue++;
      if (_errorsPostQueue < autoRepeateCount) {
        Timer(const Duration(seconds: 1), () => _postingItemQueue);
      }
    } else {
      //Если во время сохранения произошла ошибка, возвращаем несохраненные элементы в очередь
      //Но так как там уже могут быть эти же элементы, делаем это через проверку
      for (var item in _postingItems) {
        if (_postQueue.contains(item)) {
          continue;
        }
        _postQueue.add(item);
      }
      _postingItems.clear();
      _isPosting = false;
      _errorsPostQueue = 0;
      _postingItemQueue();
    }
  }

  Future<List<NsgDataItem>> loadFavorites(NsgUserSettingsController userSetiingsController, List<String> ids) async {
    var cmp = NsgCompare();
    var dataItem = NsgDataClient.client.getNewObject(dataType);
    var answerList = <NsgDataItem>[];
    var listToRequest = <String>[];
    //Проверяем нет ли избранного в items чтобы не делать лишний запрос
    for (var e in ids) {
      if (e.isEmpty) continue;
      var item = dataItemList.firstWhereOrNull((item) => item.id == e);
      if (item == null) {
        listToRequest.add(e);
      } else {
        answerList.add(item);
      }
    }
    //Дочитываем недостающие элементы
    if (listToRequest.isNotEmpty) {
      cmp.add(name: dataItem.primaryKeyField, value: listToRequest, comparisonOperator: NsgComparisonOperator.inList);
      var params = NsgDataRequestParams(compare: cmp, readNestedField: referenceList?.join(','));
      var request = NsgDataRequest<NsgDataItem>(storageType: controllerMode.storageType, dataItemType: dataType);
      answerList.addAll(await request.requestItems(filter: params));

      var newIds = answerList.map((e) => e.id).join(',');
      if (newIds != ids.join(',')) {
        var objFavorite = userSetiingsController.getFavoriteObject(dataItem.typeName);
        objFavorite.settings = newIds;
        await userSettingsController!.postUserSettings(objFavorite as NsgDataItem);
      }
    }
    return answerList;
  }

  bool isFavoritesRequested = false;
  final List<NsgDataItem> favorites = [];

  ///Список часто используемых элементов
  List<NsgDataItem> recent = [];

  ///Список избранных элементов
  Future<List<NsgDataItem>> getFavorites() async {
    if (isFavoritesRequested) {
      return favorites;
    }
    if (userSettingsController != null) {
      //Загрузка избранных
      var dataItem = NsgDataClient.client.getNewObject(dataType);
      var ids = userSettingsController!.getFavoriteIds(dataItem.typeName);
      favorites.addAll(await loadFavorites(userSettingsController!, ids));
      //Загрузка последних
      ids = userSettingsController!.getRecentIds(dataItem.typeName);
      recent.addAll(await loadFavorites(userSettingsController!, ids));

      isFavoritesRequested = true;
    }
    return favorites;
  }

  static NsgBaseControllerData emptyData = NsgBaseControllerData();

  Future<String?> beginTransaction(NsgDataProvider provider, {int lifespan = 0, NsgCancelToken? cancelToken}) async {
    var request = NsgSimpleRequest<String>();
    var newItem = await request.requestItem(
        provider: provider,
        function: '/Api/Transaction/Begin' + (lifespan > 0 ? '?lifespan=$lifespan' : ''),
        method: 'POST',
        autoRepeate: true,
        autoRepeateCount: 3,
        cancelToken: cancelToken,
        retryIf: (e) => retryRequestIf(e));
    return newItem;
  }

  Future<bool?> commitTransaction(NsgDataProvider provider, String transactionId, {NsgCancelToken? cancelToken}) async {
    var request = NsgSimpleRequest<bool>();
    var newItem = await request.requestItem(
        provider: provider,
        function: '/Api/Transaction/Commit?id=$transactionId',
        method: 'POST',
        autoRepeate: true,
        autoRepeateCount: 3,
        cancelToken: cancelToken,
        retryIf: (e) => retryRequestIf(e));
    return newItem;
  }

  Future<bool?> rollbackTransaction(NsgDataProvider provider, String transactionId, {NsgCancelToken? cancelToken}) async {
    var request = NsgSimpleRequest<bool>();
    var newItem = await request.requestItem(
        provider: provider,
        function: '/Api/Transaction/Rollback?id=$transactionId',
        method: 'POST',
        autoRepeate: true,
        autoRepeateCount: 3,
        cancelToken: cancelToken,
        retryIf: (e) => retryRequestIf(e));
    return newItem;
  }
}
