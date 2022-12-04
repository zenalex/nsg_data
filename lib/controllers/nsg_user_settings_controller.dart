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
    postUserSettings(objFavorite);
  }

  void removeFavoriteId(String typeName, String id) {}

  Future postUserSettings(NsgUserSettings objFavorite) async {
    //Поставить в очередь на сохранение, чтобы избезать параллельного сохранения настроек пользователя
    //Уменьшив таким образом нагрузку на сервер и избежать коллизий
  }
}
