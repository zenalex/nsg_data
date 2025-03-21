import '../nsg_data_item.dart';
import 'nsgDataController.dart';

class NsgDataItemController<T extends NsgDataItem> extends NsgDataController<T> {
  NsgDataItemController(
      {this.widgetId,
      super.requestOnInit = true,
      super.useUpdate = true,
      super.useChange = true,
      super.builderIDs,
      super.masterController,
      super.dataBindign,
      super.autoRepeate = false,
      super.autoRepeateCount = 10,
      super.useDataCache = false,
      super.selectedMasterRequired = true,
      super.autoSelectFirstItem = false,
      super.dependsOnControllers,
      super.controllerMode})
      : super();
  String? widgetId;
  final _dataItemControllers = <String, NsgDataItemController<T>>{};

  ///Возвращает новый экземпляр контроллера. Обязателен к переопределению
  NsgDataItemController getNewInstance() {
    throw Exception('getNewObject for type $runtimeType is not defined');
  }

  NsgDataItemController<T> getDataItemController(String widgetId) {
    if (_dataItemControllers.containsKey(widgetId)) {
      return _dataItemControllers[widgetId]!;
    }
    var instance = getNewInstance();
    instance.widgetId = widgetId;
    _dataItemControllers[widgetId] = instance as NsgDataItemController<T>;
    return _dataItemControllers[widgetId]!;
  }

  void removeDataItemController(String widgetId) {
    if (_dataItemControllers.containsKey(widgetId)) {
      _dataItemControllers.remove(widgetId);
    }
  }

  @override
  @Deprecated('Use listPageOpenDataItem instead')
  void listPageOpen(String pageName, {bool needRefreshItems = false, bool offPage = false}) {
    assert(widgetId != null);
    super.listPageOpen(pageName, needRefreshItems: needRefreshItems, offPage: offPage);
  }

  void listPageOpenDataItem(String pageName, {required String widgetId, bool needRefreshItems = false, bool offPage = false}) {
    if (this.widgetId == widgetId) {
      super.listPageOpen(pageName, needRefreshItems: needRefreshItems, offPage: offPage);
      return;
    }

    var controller = getDataItemController(widgetId);
    controller.listPageOpenDataItem(pageName, widgetId: widgetId, needRefreshItems: needRefreshItems, offPage: offPage);
  }
}
