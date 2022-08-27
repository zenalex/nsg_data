import 'package:nsg_data/nsg_data.dart';

///Контроллер для работы с объектами, содержащими картинки
///Чтение ведется в 2 этапа - сначала читаются все поля, кроме картинок, затем сами картинки
class NsgImageController<T extends NsgDataItem> extends NsgDataController<T> {
  ///Список полей
  List<String> imageFieldNames = [];

  ///Поля для чтения без полей типа картинка
  List<String> fieldsToRead = [];

  NsgImageController(
      {super.requestOnInit = true,
      super.masterController,
      super.dataBindign,
      super.autoRepeate = false,
      super.autoRepeateCount = 10,
      super.useDataCache = true,
      super.selectedMasterRequired = true,
      super.autoSelectFirstItem = false,
      super.dependsOnControllers}) {
    var elem = NsgDataClient.client.getNewObject(dataType) as T;
    for (var fieldName in elem.fieldList.fields.keys) {
      if (elem.fieldList.fields[fieldName] is NsgDataImageField) {
        imageFieldNames.add(fieldName);
      } else {
        fieldsToRead.add(fieldName);
      }
    }
  }

  @override
  Future<List<NsgDataItem>> doRequestItems() async {
    var request = NsgDataRequest(dataItemType: dataType);
    //TODO: отложенное дочитывание картинок
    return await request.requestItems(
      filter: getRequestFilter,
      loadReference: referenceList,
      autoRepeate: autoRepeate,
      autoRepeateCount: autoRepeateCount,
      userRetryIf: (e) => retryRequestIf(e),
    );
  }

  // Future loadImages(){

  // }
}
