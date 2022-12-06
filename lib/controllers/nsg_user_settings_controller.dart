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
      super.controllerMode})
      : super() {
    assert(NsgDataClient.client.getNewObject(T) is NsgUserSettings);
  }

  Map<String, dynamic> settingsMap = {};

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
  Future<bool> itemPagePost({bool goBack = true, bool useValidation = true}) async {
    (currentItem as NsgUserSettings).settings = jsonEncode(settingsMap);
    currentItem.storageType = controllerMode.storageType;
    return await super.itemPagePost(goBack: goBack, useValidation: useValidation);
  }

  static const String _favoriteSettingsName = '_favorites_';

  ///Возвращает список идентификоторов, занесенных в избранное по данному типу данных
  List<String> getFavoriteIds(String typeName) {
    var keyName = _favoriteSettingsName + typeName;
    var objFavorite = items.firstWhere((e) => (e as NsgUserSettings).name == keyName, orElse: () {
      var obj = NsgDataClient.client.getNewObject(T) as T;
      obj.newRecord();
      (obj as NsgUserSettings).name = keyName;
      return obj;
    }) as NsgUserSettings;
    return objFavorite.settings.split(',');
  }
  
  void addFavoriteId(String typeName, String id) {
    var keyName = _favoriteSettingsName + typeName;
    var objFavorite = items.firstWhere((e) => (e as NsgUserSettings).name == keyName, orElse: () {
      var obj = NsgDataClient.client.getNewObject(T) as T;
      obj.newRecord();
      (obj as NsgUserSettings).name = keyName;
      return obj;
    }) as NsgUserSettings;
    if (objFavorite.settings.contains(id)) {
      return;
    }
    var ids = objFavorite.settings.split(',');
    ids.add(id);
    objFavorite.settings += ids.join(',');
    postUserSettings(objFavorite as T);
  }

  void removeFavoriteId(String typeName, String id) {}

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
        var p = NsgDataPost(dataItemType: runtimeType);
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
    } finally {}
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
}
