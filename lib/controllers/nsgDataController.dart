// ignore_for_file: file_names

import 'package:get/get.dart';
import 'package:nsg_data/nsg_data.dart';

class NsgDataController<T extends NsgDataItem> extends NsgBaseController {
  ///Массив данный. После того как контроллер переходит в статус  successful, данные могут использоваться
  ///Представляет собой типизированный вариант массива dataItemList
  List<T> get items => dataItemList.cast<T>();

  final List<T> _favorites = [];

  ///Список избранных элементов
  Future<List<T>> getFavorites() async {
    if (_favorites.isNotEmpty) {
      return _favorites;
    }
    // if (userSettingsController != null) {
    //   var ids = userSettingsController!.getFavorites(dataType);
    //   _favorites.addAll(await loadFavorites(ids));
    // }
    return _favorites;
  }

  ///Список часто используемых элементов
  List<T> recent = [];

  ///Первый элемент из items. Если items  пустой: вернет новый пустой элемент данных  типа T
  T get firstItem => (dataItemList.isEmpty) ? NsgDataClient.client.getNewObject(dataType) as T : items[0];

  ///Текущий элемент (например, элемент для отображения на форме элемента)
  ///Представляет из себя типизированный аналой selectedItem.
  ///Если selectedItem null, то вернет пустое значение типа T
  T get currentItem => ((selectedItem ?? NsgDataClient.client.getNewObject(dataType)) as T);

  ///Установка текущего элемента для контроллера
  set currentItem(T item) => selectedItem = item;

  ///Контроллер настроек пользователя. Если задан, используется для хранения и извлечения информации
  ///об избранных элементах и последних используемых
  final NsgUserSettingsController? userSettingsController;

  NsgDataController(
      {bool requestOnInit = true,
      bool useUpdate = true,
      bool useChange = true,
      List<String>? builderIDs,
      NsgBaseController? masterController,
      NsgDataBinding? dataBindign,
      bool autoRepeate = false,
      int autoRepeateCount = 10,
      bool useDataCache = false,
      bool selectedMasterRequired = true,
      bool autoSelectFirstItem = false,
      List<NsgBaseController>? dependsOnControllers,
      super.controllerMode,
      this.userSettingsController})
      : super(
            dataType: T,
            requestOnInit: requestOnInit,
            useUpdate: useUpdate,
            useChange: useChange,
            masterController: masterController,
            dataBinding: dataBindign,
            autoRepeate: autoRepeate,
            autoRepeateCount: autoRepeateCount,
            selectedMasterRequired: selectedMasterRequired,
            useDataCache: useDataCache,
            autoSelectFirstItem: autoSelectFirstItem,
            dependsOnControllers: dependsOnControllers);

  ///Сделать текущим предыдущий элемент
  void gotoPrevItem() {
    var index = items.indexOf(currentItem);
    if (index == 0) return;
    setAndRefreshSelectedItem(items[index - 1], null);
  }

  ///Сделать текущим следующий элемент
  void gotoNextItem() {
    var index = items.indexOf(currentItem);
    if (index >= items.length - 1) return;
    setAndRefreshSelectedItem(items[index + 1], null);
  }

  ///Есть ли в списке элементы до текущего
  bool canGoPrevItem() {
    var index = items.indexOf(currentItem);
    return index > 0;
  }

  ///Есть ли в списке элементы после текущего
  bool canGoNextItem() {
    var index = items.indexOf(currentItem);
    return index >= 0 && index < items.length - 1;
  }

  ///Cоздает новый элемент и открывает страницу для его редактирования
  ///В зависимости от свойства объекта createOnServer создание нового объекта может происходить на сервере
  void itemNewPageOpen(String pageName) {
    createNewItemAsync();
    Get.toNamed(pageName);
  }

  ///Создает новый элемент. Используется, например, при нажатии добавить в форме списка
  ///На время создания (так как оно может быть связано с запросом на сервер) устанавливает статус контроллера в loading
  ///Для непосредственного создания нового элемента вызывает асинхронный метод doCreateNewItem, который может быть перекрыт
  ///для организации бизнес-логики запросов
  Future<T> createNewItemAsync() async {
    currentStatus = RxStatus.loading();
    sendNotify();
    try {
      var elem = await doCreateNewItem();
      currentStatus = RxStatus.success();
      currentItem = elem.clone() as T;

      backupItem = elem;
      sendNotify();
      selectedItemChanged.broadcast(null);
      return elem;
    } catch (e) {
      var msg = '';
      if (e is NsgApiException && e.error.message != null) {
        msg = e.error.message!;
      }
      currentStatus = RxStatus.error(msg);
      sendNotify();
    }
    return NsgDataClient.client.getNewObject(dataType) as T;
  }

  ///Создает новый элемент. Вызывается из createNewItem
  ///Может быть перекрыт для организации бизнес-логики запросов, например, заполнения нового элемента на сервере
  ///или проверки возможности создания нового элемента
  Future<T> doCreateNewItem() async {
    var elem = NsgDataClient.client.getNewObject(dataType) as T;
    //Если выставлен признак создавать на сервере, создаем запрос на сервер
    if (elem.createOnServer) {
      var request = NsgDataRequest<T>();
      elem = await request.requestItem(method: 'POST', function: elem.apiRequestItems + '/Create');
    } else {
      elem.newRecordFill();
    }
    elem.state = NsgDataItemState.create;
    elem.storageType = controllerMode.storageType;
    return elem;
  }

  ///Добавить элемент в избранное
  void toggleFavorite(T item) {
    if (!_favorites.contains(item)) {
      _favorites.add(item);
      userSettingsController?.addFavoriteId(item.typeName, item.id);
    } else {
      _favorites.remove(item);
      userSettingsController?.removeFavoriteId(item.typeName, item.id);
    }
  }

  ///Добавить элемент в часто используемые
  void addRecent(T item) {
    if (!recent.contains(item)) {
      recent.add(item);
    }
  }

  Future<List<T>> loadFavorites(List<String> ids) async {
    var cmp = NsgCompare();
    var dataItem = NsgDataClient.client.getNewObject(dataType);
    cmp.add(name: dataItem.typeName, value: ids, comparisonOperator: NsgComparisonOperator.inList);
    var params = NsgDataRequestParams(compare: cmp, readNestedField: referenceList?.join(','));
    var request = NsgDataRequest<T>(storageType: controllerMode.storageType);
    return await request.requestItems(filter: params);
  }
}
