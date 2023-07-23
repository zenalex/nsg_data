// ignore_for_file: file_names

import 'dart:collection';

import 'package:nsg_data/nsg_data.dart';

///Контроллер для работы с объектами, содержащими картинки
///Чтение ведется в 2 этапа - сначала читаются все поля, кроме картинок, затем сами картинки
class NsgImageController<T extends NsgDataItem> extends NsgDataController<T> {
  ///Список полей, содержащих изображения. Формируется автоматически в конструкторе.
  ///Эти поля не будут читаться при основном запросе, а будут дочитаны фоново отдельными запросами
  List<String> imageFieldNames = [];

  ///Поля для чтения основым запросом. Не должны содержать полей типа картинка. Формируется автоматически в конструкторе.
  List<String> fieldsToRead = [];

  ///Если параметр true, то чтение картинок будет и дти отдельными фоновыми запросами по факту необходимости
  ///их отображения в NsgImage. При этом команда обновления будет подаваться конкретному NsgImage
  ///Максимальное количество одновременно запрашиваемых картинок ограничивается maxСoncurrentlyRequests
  bool lateImageRead;

  ///Максимальное количество одновременно запрашиваемых картинок в случае их отложенного чтения
  int maxConcurrentlyRequests;

  ///Очередь картинок на чтение в режиме отложенного чтения
  final _imageQueue = Queue<ImageQueueParam>();
  final _requestList = <ImageQueueParam>[];
  String nameId = '';

  NsgImageController(
      {super.requestOnInit = true,
      super.masterController,
      super.dataBindign,
      super.autoRepeate = false,
      super.autoRepeateCount = 10,
      super.useDataCache = false,
      super.selectedMasterRequired = true,
      super.autoSelectFirstItem = false,
      super.dependsOnControllers,
      this.lateImageRead = false,
      this.maxConcurrentlyRequests = 5}) {
    var elem = NsgDataClient.client.getNewObject(dataType) as T;
    for (var fieldName in elem.fieldList.fields.keys) {
      if (elem.fieldList.fields[fieldName] is NsgDataImageField) {
        imageFieldNames.add(fieldName);
      } else {
        fieldsToRead.add(fieldName);
      }
    }
    nameId = elem.primaryKeyField;
  }

  @override
  Future<List<NsgDataItem>> doRequestItems({NsgDataRequestParams? filter}) async {
    var request = NsgDataRequest(dataItemType: dataType);
    var list = await request.requestItems(
      filter: filter ?? getRequestFilter,
      loadReference: referenceList,
      autoRepeate: autoRepeate,
      autoRepeateCount: autoRepeateCount,
      userRetryIf: (e) => retryRequestIf(e),
    );
    if (lateImageRead) {
      //В случае отложенного чтения проверяем не была ли картинка уже загружена и проставляем статус в объект
    }
    return list;
  }

  @override
  NsgDataRequestParams get getRequestFilter {
    var filter = super.getRequestFilter;
    if (lateImageRead) {
      //При отложенном чтении не читаем поля с картинками, дочитываем их позже отдельными запросами
      filter.fieldsToRead = fieldsToRead.join(',');
    }
    return filter;
  }

  void addImageToQueue(ImageQueueParam imageQueueParam) {
    //Проверяем на наличие картинки в списке на дочитываение
    if (_imageQueue.any((e) => e.id == imageQueueParam.id && e.fieldName == imageQueueParam.fieldName)) return;
    //Если картинка ранее не читалась и отсутствует в кэше, добавляем ее в список на чтение
    _imageQueue.add(imageQueueParam);
    startImageQueueRead();
  }

  ///Запуск фонового чтения картинки из очереди
  Future startImageQueueRead() async {
    if (_requestList.length < maxConcurrentlyRequests && _imageQueue.isNotEmpty) {
      //Если количество текущих запросов меньше максимального, запрашиваем картинку из очереди
      var item = _imageQueue.removeFirst();
      startImageRequest(item);
    }
  }

  ///Запуск запроса чтения картинки с сервера
  Future startImageRequest(ImageQueueParam imageQueueParam) async {
    _requestList.add(imageQueueParam);
    var cmp = NsgCompare();
    cmp.add(name: nameId, value: imageQueueParam.id);
    var fields = '$nameId,${imageQueueParam.fieldName}';
    //if (!items.any((e) => e.id == imageQueueParam.id)) {
    fields += ',' + fieldsToRead.join(',');
    //}
    var filter = NsgDataRequestParams(compare: cmp, readNestedField: fields);
    var req = NsgDataRequest(dataItemType: dataType);
    var item = await req.requestItem(filter: filter);
    if (items.contains(item)) {
      var oldItem = items.firstWhere((e) => e.id == item.id);
      oldItem[imageQueueParam.fieldName] = item[imageQueueParam.fieldName];
    } else {
      items.add(item as T);
    }
    _requestList.remove(imageQueueParam);
    startImageQueueRead();
    sendNotify(keys: [NsgUpdateKey(id: item.id.toString(), type: NsgUpdateKeyType.element)]);
    //var oldItem =
  }

  ImageStatus getImageStatus(NsgDataItem item, String fieldName) {
    if (_requestList.any((e) => e.id == item.id && e.fieldName == fieldName) || _imageQueue.any((e) => e.id == item.id && e.fieldName == fieldName)) {
      return ImageStatus.loading;
    }

    return ImageStatus.empty;
  }
}

///Класс параметров картинки, назначенной для отложенного чтения
class ImageQueueParam {
  String id;
  String fieldName;
  NsgDataRequest? request;

  ImageQueueParam(this.id, this.fieldName);
}

enum ImageStatus { empty, loading, successful, error }
