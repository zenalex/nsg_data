import 'package:nsg_data/nsg_data.dart';

class NsgDataUntypedReferenceField extends NsgDataReferenceField {
  NsgDataUntypedReferenceField(super.name, {this.defaultReferentType = NsgDataItem});

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  @override
  Type get referentElementType => NsgDataItem;

  @override
  Type get referentType => NsgDataItem;

  ///Объект какого типа возвращать, если будет рапрошен метод getReferent у незаполненной ссылки
  Type defaultReferentType;

  Type get realDefaultReferentType => defaultReferentType == NsgDataItem ? NsgDataClient.client.registeredDataItems.first.runtimeType : defaultReferentType;

  @override
  NsgDataItem? getReferent(NsgDataItem dataItem, {bool useCache = true, bool allowNull = false}) {
    var id = dataItem.getFieldValue(name).toString();
    var uid = UntypedId(id);

    //Если тип не указан, возвращаем null
    if (uid.referentType == null) {
      if (allowNull) {
        return null;
      } else {
        return NsgDataClient.client.getNewObject(realDefaultReferentType);
      }
    }
    if (uid.guid == Guid.Empty || uid.guid == '') {
      return NsgDataClient.client.getNewObject(uid.referentType!);
    }
    if (useCache) {
      var item = NsgDataClient.client.getItemsFromCache(uid.referentType!, uid.guid, allowNull: true);
      if (item != null) return item;
      //Вызывающий готов к отсутствию — отсутствие для него не дефект. Сообщать
      //здесь НЕЛЬЗЯ: с allowNull кэш щупает сам загрузчик, решая что дочитывать,
      //и такая проба заведомо раньше экрана. Дедуп NsgFieldUsage пропускает
      //только ПЕРВОЕ событие пары «тип.поле» за сессию, поэтому проба съедала бы
      //слот настоящего промаха — на этом уже встали 42 задачи (#1547). Разбор —
      //в NsgDataReferenceField.getReferent, здесь ровно тот же случай.
      if (allowNull) return null;
      //Ссылка задана, объекта нет, и сейчас вернётся ПУСТЫШКА.
      //
      //До #1751 отсюда не уходило НИЧЕГО: типизированная ссылка звала
      //reportMissingReferent, а этот override — нет, он получал пустышку прямо
      //из getItemsFromCache(allowNull: false) и молча её возвращал. То есть у
      //нетипизированных ссылок промах не оставлял ни лога в debug, ни события в
      //релизе, хотя это тот же дефект выборки и заметить его ровно так же нечем.
      NsgFieldUsage.reportMissingReferent(dataItem.typeName, name);
      assert(!NsgFieldUsage.strictEmptyFields,
          '!!! Промах референта: ссылка $name задана, объекта нет в кэше. Объект: ${dataItem.typeName}');
      return NsgDataClient.client.getNewObject(uid.referentType!);
    } else {
      if (allowNull) {
        return null;
      } else {
        return NsgDataClient.client.getNewObject(realDefaultReferentType);
      }
    }
  }

  NsgDataItem? getNewReferent(NsgDataItem dataItem) {
    var id = dataItem.getFieldValue(name).toString();
    var uid = UntypedId(id);
    if (uid.referentType == null) return null;
    return NsgDataClient.client.getNewObject(uid.referentType!);
  }

  ///Референт по нетипизированной ссылке; если объекта нет в кэше — дочитывает.
  ///
  ///Те же три дефекта, что и у типизированной версии, и по той же причине —
  ///ветка загрузки была мертва, поэтому внутри неё никто ничего не проверял.
  ///Разбор целиком — в NsgDataReferenceField.getReferentAsync
  ///(NSG-SOFT/futbolista-tasks#1921).
  @override
  Future<NsgDataItem> getReferentAsync(NsgDataItem dataItem, {bool useCache = true}) async {
    NsgFieldUsage.reportAsyncReferentDuringBuild(dataItem.typeName, name);
    if (useCache) {
      //allowNull: true — иначе промах кэша возвращает пустышку, а не null, и
      //ветка ниже недостижима. Плюс #1547: проба загрузчика не должна
      //расходовать единственное событие промаха на пару «тип.поле».
      var cached = getReferent(dataItem, allowNull: true);
      if (cached != null) return cached;
    }

    var uid = UntypedId(dataItem.getFieldValue(name).toString());
    //Тип не выбран — дочитывать нечего и негде: у нетипизированной ссылки тип
    //живёт в самом значении. В релизе assert молчит, и здесь стояло
    //`uid.referentType!` — то есть падение вместо пустого объекта.
    assert(uid.referentType != null, 'Запрос getReferent у untypedReference с невыбранным типом');
    if (uid.referentType == null) return NsgDataClient.client.getNewObject(realDefaultReferentType);

    //По первичному ключу РЕФЕРЕНТА. Стояло имя поля ВЛАДЕЛЬЦА: для
    //`NotificationItem.notificationObjId` это давало условие по
    //`Objective.notificationObjId` — поля с таким именем у референта нет.
    var referent = NsgDataClient.client.getNewObject(uid.referentType!);
    var cmp = NsgCompare();
    cmp.add(name: referent.primaryKeyField, value: uid.guid);
    var filter = NsgDataRequestParams(compare: cmp);
    var request = NsgDataRequest(dataItemType: uid.referentType!);
    var loaded = await request.requestItems(filter: filter, loadReference: []);

    var item = NsgDataClient.client.getItemsFromCache(uid.referentType!, uid.guid, allowNull: true) ?? loaded.firstOrNull;
    //Объекта может не быть и после запроса. Пустышка, а не `item!`, который
    //ронял `Null check operator used on a null value`.
    return item ?? NsgDataClient.client.getNewObject(uid.referentType!);
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name).toString();
    var valueB = b.getFieldValue(name).toString();
    return valueA.compareTo(valueB);
  }
}

///Идентификатор ссылки  неопределенного типа.
///Должен состооять из идентификатора и типа данных, разделенными точкой. Например,
///GUID.ExanpleItem
class UntypedId {
  String guid = '';
  Type? referentType;

  UntypedId(String id) {
    //print('UUID = $id');
    if (id == '') {
      return;
    }
    var idSplitted = id.split('.');
    assert(idSplitted.length <= 2, 'Id untyped reference не может соодержать больше 2 частей (guid.type)');
    guid = idSplitted[0];
    if (idSplitted.length == 2) {
      referentType = idSplitted[1].isEmpty ? null : NsgDataClient.client.getTypeByServerName(idSplitted[1]);
    }
  }
}
