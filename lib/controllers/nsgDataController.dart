// ignore_for_file: file_names

import 'package:flutter/widgets.dart';
import 'package:nsg_data/controllers/nsg_controller_status.dart';
import 'package:nsg_data/nsg_data.dart';

class NsgDataController<T extends NsgDataItem> extends NsgBaseController {
  ///Массив данный. После того как контроллер переходит в статус  successful, данные могут использоваться
  ///Представляет собой типизированный вариант массива dataItemList
  List<T> get items => dataItemList.cast<T>();

  ///Первый элемент из items. Если items  пустой: вернет новый пустой элемент данных  типа T
  T get firstItem => (dataItemList.isEmpty) ? NsgDataClient.client.getNewObject(dataType) as T : items[0];

  ///Текущий элемент (например, элемент для отображения на форме элемента)
  ///Представляет из себя типизированный аналой selectedItem.
  ///Если selectedItem null, то вернет пустое значение типа T
  T get currentItem => ((selectedItem ?? NsgDataClient.client.getNewObject(dataType)) as T);

  ///Установка текущего элемента для контроллера
  set currentItem(T item) => selectedItem = item;

  NsgDataController({
    bool requestOnInit = true,
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
  }) : super(
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
  void itemNewPageOpen(BuildContext context, String pageName) {
    createNewItemAsync();
    NsgNavigator.instance.toPage(context, pageName);
  }

  ///Создает новый элемент. Используется, например, при нажатии добавить в форме списка
  ///На время создания (так как оно может быть связано с запросом на сервер) устанавливает статус контроллера в loading
  ///Для непосредственного создания нового элемента вызывает асинхронный метод doCreateNewItem, который может быть перекрыт
  ///для организации бизнес-логики запросов
  Future<T> createNewItemAsync() async {
    currentStatus = NsgControillerStatus.loading;
    sendNotify();
    try {
      var elem = await doCreateNewItem();
      currentStatus = NsgControillerStatus.success;
      currentItem = elem.clone() as T;

      backupItem = elem;
      sendNotify();
      selectedItemChanged.broadcast(null);
      return currentItem;
    } catch (e) {
      var msg = '';
      if (e is NsgApiException && e.error.message != null) {
        msg = e.error.message!;
      }
      errorDescription = msg;
      currentStatus = NsgControillerStatus.error;
      sendNotify();
    }
    return NsgDataClient.client.getNewObject(dataType) as T;
  }

  ///Добавить элемент в избранное
  void toggleFavorite(T item) {
    if (!favorites.contains(item)) {
      favorites.add(item);
      userSettingsController?.addFavoriteId(item.typeName, item.id);
    } else {
      favorites.remove(item);
      userSettingsController?.removeFavoriteId(item.typeName, item.id);
    }
  }

  ///Добавить элемент в часто используемые
  void addRecent(T item) {
    if (userSettingsController == null) {
      return;
    }
    if (recent.contains(item)) {
      recent.remove(item);
    }
    recent.insert(0, item);
    while (userSettingsController!.maxRecent < recent.length) {
      recent.removeLast();
    }
    userSettingsController!.addRecentId(item.typeName, item.id);
  }

  // @override
  // Future<List<NsgDataItem>> doRequestItems() async {
  //   var newItems = await super.doRequestItems();
  //   await getFavorites();
  //   return newItems;
  // }

  // @override
  // Future requestItems({List<NsgUpdateKey>? keys}) async {
  //   await super.requestItems(keys: keys);
  //   await getFavorites();
  // }
}
