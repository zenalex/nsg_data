import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:nsg_data/nsg_data.dart';

///Контроллер для управления настройками пользователя
class NsgUserSettingsController<T extends NsgDataItem> extends NsgDataController<T> {
  NsgUserSettingsController(
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
      super.masterController,
      super.controllerMode,
      this.maxFavotrites = 100,
      this.maxRecent = 25})
      : super() {
    assert(NsgDataClient.client.getNewObject(T) is NsgUserSettings);
  }

  Map<String, dynamic> settingsMap = {};

  ///Максимально разрешенное число избранныъ элементов объектов одного типа. По умолчанию = 100
  final int maxFavotrites;

  ///Максимально число хранимых объектов одного типа в списке последних используемых. По умолчанию = 25
  final int maxRecent;

  ///Настройки пользователя в виде MAP
  var userSettings = <String, T>{};

  ///Сохранить настройку по имени. Если не существует, создаст новую запись.
  Future<void> setSettingItem(String name, String value, {NsgDataStorageType? storageType}) async {
    if (getSettingItem(name) == null) {
      var item = await doCreateNewItem() as NsgUserSettings;
      item.name = name;
      item.settings = value;
      (item as T).storageType = storageType ?? controllerMode.storageType;
      userSettings[item.name] = item as T;
      await postUserSettings(userSettings[item.name]!);
    } else {
      var item = getSettingItem(name) as NsgUserSettings;
      item.settings = value;
      (item as T).storageType = storageType ?? controllerMode.storageType;
      userSettings[item.name] = item as T;
      await postUserSettings(userSettings[item.name]!);
    }
  }

  ///Получить настройку по имени. Если не существует, вернет null
  dynamic getSettingItem(String settingName) {
    return userSettings[settingName];
  }

  ///Удалить настройку по имени.
  void removeSettingItem(String settingName) {}

  @override
  Future afterRequestItems(List<NsgDataItem> newItemsList) async {
    await super.afterRequestItems(newItemsList);
    if (newItemsList.isNotEmpty) {
      currentItem = newItemsList.first as T;
    } else {
      selectedItem = currentItem;
      newItemsList.add(selectedItem as T);
    }
    if ((currentItem as NsgUserSettings).settings.isNotEmpty) {
      try {
        settingsMap = jsonDecode((currentItem as NsgUserSettings).settings);
      } catch (e) {
        debugPrint('Ошибка загрузки настроек пользователя');
      }
    }
    return;
  }

  @override
  Future<bool> itemPagePost(BuildContext context, {bool goBack = true, bool useValidation = true}) async {
    (currentItem as NsgUserSettings).settings = jsonEncode(settingsMap);
    currentItem.storageType = controllerMode.storageType;
    return await super.itemPagePost(context, goBack: goBack, useValidation: useValidation);
  }

  static const String _favoriteSettingsName = '_favorites_';
  static const String _recentSettingsName = '_recent_';

  NsgUserSettings getUserSettingsObject(String key) {
    var obj = items.firstWhere((e) => (e as NsgUserSettings).name == key, orElse: () {
      var obj = NsgDataClient.client.getNewObject(T) as T;
      obj.newRecord();
      (obj as NsgUserSettings).name = key;
      items.add(obj);
      return obj;
    }) as NsgUserSettings;
    return obj;
  }

  NsgUserSettings getFavoriteObject(String typeName) {
    return getUserSettingsObject(_favoriteSettingsName + typeName);
  }

  NsgUserSettings getRecentObject(String typeName) {
    return getUserSettingsObject(_recentSettingsName + typeName);
  }

  ///Возвращает список идентификоторов, занесенных в избранное по данному типу данных
  List<String> getFavoriteIds(String typeName) {
    var objFavorite = getFavoriteObject(typeName);
    var s = objFavorite.settings;
    return s.isEmpty ? [] : s.split(',');
  }

  ///Возвращает список идентификоторов последних используемых объектов данного типа
  List<String> getRecentIds(String typeName) {
    var obj = getRecentObject(typeName);
    var s = obj.settings;
    return s.isEmpty ? [] : s.split(',');
  }

  ///Добавить объект в избранные и сохранить на сервере (БД)
  void addFavoriteId(String typeName, String id) {
    var objFavorite = getFavoriteObject(typeName);
    if (objFavorite.settings.contains(id)) {
      return;
    }
    var ids = objFavorite.settings.isEmpty ? [] : objFavorite.settings.split(',');
    if (ids.length >= maxFavotrites) {
      throw Exception("Превышено максимальное число элементов в избранном ($maxFavotrites)");
    }
    ids.add(id);
    objFavorite.settings = ids.join(',');
    postUserSettings(objFavorite as T);
  }

  ///Добавить объект в последние используемые и сохранить на сервере (БД)
  void addRecentId(String typeName, String id) {
    var obj = getRecentObject(typeName);
    var ids = obj.settings.isEmpty ? [] : obj.settings.split(',');
    if (ids.contains(id)) {
      if (ids.first == id) {
        return;
      }
      ids.remove(id);
    }
    ids.insert(0, id);
    while (ids.length > maxRecent) {
      ids.removeLast();
    }
    obj.settings = ids.join(',');
    postUserSettings(obj as T);
  }

  void removeFavoriteId(String typeName, String id) {
    var objFavorite = getFavoriteObject(typeName);
    if (objFavorite.settings.isEmpty || !objFavorite.settings.contains(id)) {
      return;
    }
    var ids = objFavorite.settings.split(',');
    ids.remove(id);
    objFavorite.settings = ids.join(',');
    postUserSettings(objFavorite as T);
  }

  final List<T> _settingsPostQueue = [];
  final List<T> _settingsPostingItems = [];
  bool _isSettingsPosting = false;

  ///Поставить в очередь на сохранение, чтобы избезать параллельного сохранения настроек пользователя
  ///Уменьшив таким образом нагрузку на сервер и избежать коллизий
  Future postUserSettings(T objFavorite) async {
    if (_settingsPostQueue.contains(objFavorite)) {
      return;
    }
    _settingsPostQueue.add(objFavorite);
    if (_isSettingsPosting) {
      return;
    }
    _postingUserSettings();
  }

  int _errorsPostUserSettings = 0;
  int maxErrorsPostUserSettings = 10;
  Future _postingUserSettings() async {
    if (_isSettingsPosting) {
      return true;
    }
    if (_settingsPostQueue.isEmpty) {
      _isSettingsPosting = false;
      return;
    }
    _isSettingsPosting = true;
    var error = false;
    try {
      //Переносим массив сохраняемых элементов в отдельный список
      _settingsPostingItems.addAll(_settingsPostQueue);
      //Очищаем очередь, чтобы избежать повторного сохранения
      _settingsPostQueue.clear();
      //Непосредственно сохранение
      if (controllerMode.storageType == NsgDataStorageType.server) {
        var p = NsgDataPost(dataItemType: dataType);
        p.itemsToPost = _settingsPostingItems;
        await p.postItems();
      } else {
        await NsgLocalDb.instance.postItems(_settingsPostingItems);
      }

      for (var item in _settingsPostingItems) {
        item.state = NsgDataItemState.fill;
      }
      _settingsPostingItems.clear();
    } catch (e) {
      error = true;
    } finally {
      _isSettingsPosting = false;
    }
    if (error) {
      _errorsPostUserSettings++;
      if (_errorsPostUserSettings < maxErrorsPostUserSettings) {
        Timer(const Duration(seconds: 1), () => _postingUserSettings);
      }
    } else {
      //Если во время сохранения произошла ошибка, возвращаем несохраненные элементы в очередь
      //Но так как там уже могут быть эти же элементы, делаем это через проверку
      for (var item in _settingsPostingItems) {
        if (_settingsPostQueue.contains(item)) {
          continue;
        }
        _settingsPostQueue.add(item);
      }
      _settingsPostingItems.clear();
      _isSettingsPosting = false;
      _errorsPostUserSettings = 0;
      _postingUserSettings();
    }
  }

  @override
  Future requestItems({List<NsgUpdateKey>? keys}) async {
    await super.requestItems(keys: keys);
    //Проверка на наличие одинаковых записей
    //В случае обнаружения, дубликаты удаляем
    var itemsToRemove = <T>[];
    for (var item in items) {
      var nus = item as NsgUserSettings;
      if (userSettings.containsKey(nus.name)) {
        itemsToRemove.add(item);
        continue;
      }
      userSettings[nus.name] = item;
    }
    if (itemsToRemove.isNotEmpty) {
      await deleteItems(itemsToRemove);
    }
  }
}
