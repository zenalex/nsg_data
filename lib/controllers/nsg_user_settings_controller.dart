import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:nsg_data/nsg_data.dart';

///Контроллер для управления настройками пользователя
class NsgUserSettingsController<T extends NsgDataItem> extends NsgDataController<T> {
  NsgUserSettingsController({
    super.requestOnInit,
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
  }) : super() {
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
    return await super.itemPagePost(goBack: goBack, useValidation: useValidation);
  }
}
