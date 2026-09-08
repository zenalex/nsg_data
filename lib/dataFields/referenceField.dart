// ignore_for_file: file_names

import 'package:nsg_data/nsg_data.dart';

class NsgDataReferenceField<T extends NsgDataItem> extends NsgDataBaseReferenceField {
  NsgDataReferenceField(super.name);

  @override
  dynamic convertJsonValue(dynamic jsonValue) {
    return jsonValue.toString();
  }

  @override
  dynamic get defaultValue => '';

  @override
  Type get referentElementType => T;

  @override
  Type get referentType => T;

  T? getReferent(NsgDataItem dataItem, {bool useCache = true, bool allowNull = false}) {
    var id = dataItem.getFieldValue(name).toString();
    if (id == '' || id == Guid.Empty) {
      if (allowNull) {
        return null;
      }
      return NsgDataClient.client.getNewObject(T) as T;
    }
    if (useCache) {
      //Спрашиваем кэш с allowNull, даже если вызывающий хочет пустышку: так промах
      //виден здесь, а не подменяется молча новым объектом внутри кэша.
      //Читаем с учётом наследования (#1548): объект мог лечь в ведро наследника,
      //если сервер вернул расширенный тип. Обычный getItemsFromCache смотрит
      //только ведро T и посчитал бы это промахом — с постоянным перезапросом.
      var item = NsgDataClient.client.getItemsFromCacheTyped<T>(id, allowNull: true);
      if (item != null) return item;
      //Вызывающий готов к отсутствию — отсутствие для него не дефект, и молчаливой
      //пустоты на экране не будет: formattedValue напечатает сырой id, а
      //getReferentOrNull отдаст null, который вызывающий обработает сам.
      //
      //Сообщать здесь НЕЛЬЗЯ, и это не мелочь. С allowNull кэш щупает сам
      //загрузчик, решая, что дочитывать (nsg_data_request.dart, nsg_data_item.dart —
      //ветки loadAllReferents). Такая проба заведомо срабатывает раньше, чем данные
      //дойдут до экрана, а дедуп в NsgFieldUsage пропускает только ПЕРВОЕ событие
      //пары «тип.поле» за сессию. В итоге диагностика рапортовала о собственной
      //пробе, а настоящий промах экрана глотала как дубль — и в отчёт уезжало поле,
      //которое в referenceList присутствует. На этом встали 42 задачи (#1547).
      if (allowNull) return null;
      //Ссылка задана, объекта нет, и сейчас мы вернём ПУСТЫШКУ: экран нарисует
      //пустоту без единой ошибки. Ровно этот случай диагностика и ловит.
      //В удачном пути сюда не заходим, поэтому она ничего не стоит и работает
      //в том числе в релизе.
      NsgFieldUsage.reportMissingReferent(dataItem.typeName, name, owner: dataItem);
      //Строгий режим ронял только чтение незапрошенного ПОЛЯ
      //(nsg_data_item.dart, ветка emptyFields), а промах референта проходил
      //мимо — хотя это тот же класс дефекта и заметить его труднее: поле хотя бы
      //пустое, а здесь возвращается валидный с виду объект с нулевыми полями.
      //
      //Порядок тот же, что у поля: сначала отчёт, потом падение. Assert обрывает
      //поддерево на первом нарушении и прячет остальные, поэтому для ПОИСКА
      //промахов годится лог, а не он (NSG-SOFT/futbolista-tasks#1751).
      assert(!NsgFieldUsage.strictEmptyFields,
          '!!! Промах референта: ссылка $name задана, объекта нет в кэше. Объект: ${dataItem.typeName}');
      return NsgDataClient.client.getNewObject(T) as T;
    } else {
      return null;
    }
  }

  ///Референт по ссылке; если объекта нет в кэше — дочитывает его с сервера.
  ///
  ///⚠️ До NSG-SOFT/futbolista-tasks#1921 метод не дочитывал НИЧЕГО, вопреки имени.
  ///Ветка загрузки стояла под `if (item == null)`, а `getReferent` звался без
  ///`allowNull`, то есть с `allowNull: false` — при котором промах кэша
  ///возвращает не null, а пустышку `getNewObject(T)`. Условие не выполнялось
  ///никогда, запрос не уходил, и вызывающий получал тот же пустой объект, что и
  ///от синхронного геттера, плюс событие промаха в диагностике. Метод был
  ///синхронным геттером в обёртке `Future`.
  ///
  ///Чинить это по частям нельзя: оживи одну только ветку — и заработали бы ещё
  ///два дефекта, которые до сих пор были не видны, потому что код был мёртв.
  ///Оба исправлены здесь же, см. комментарии ниже.
  Future<T> getReferentAsync(NsgDataItem dataItem, {bool useCache = true}) async {
    //Сетевой вызов из сборки кадра — предупредить в debug. На входе, а не перед
    //запросом: при тёплом кэше запрос не уйдёт и вызов «сработает», но место
    //вызова от этого верным не станет.
    NsgFieldUsage.reportAsyncReferentDuringBuild(dataItem.typeName, name);
    var id = dataItem.getFieldValue(name).toString();
    //Пустая ссылка — законное состояние, а не непрочитанные данные: идти за ней
    //на сервер незачем. Ровно та же ветка, что и в getReferent.
    if (id == '' || id == Guid.Empty) return NsgDataClient.client.getNewObject(T) as T;

    if (useCache) {
      //allowNull: true, и это принципиально. Здесь кэш щупает ЗАГРУЗЧИК, решая,
      //надо ли дочитывать, — а такую пробу #1547 запретил превращать в отчёт о
      //промахе: дедуп в NsgFieldUsage пропускает только ПЕРВОЕ событие пары
      //«тип.поле» за сессию, и проба съедала его раньше, чем промах случался на
      //экране. Заодно это и есть то самое null, ради которого ветка ниже писалась.
      var cached = getReferent(dataItem, allowNull: true);
      if (cached != null) return cached;
    }

    //Фильтр — по ПЕРВИЧНОМУ КЛЮЧУ типа референта. Здесь стояло имя поля
    //ВЛАДЕЛЬЦА (`cmp.add(name: name, ...)`): для `Objective.objectiveTypeId` это
    //давало условие по `ObjectiveType.objectiveTypeId` — поля с таким именем у
    //референта нет вовсе, — а у самоссылки `Tournament.mainTournamentId`
    //отбирало ДЕТЕЙ искомого турнира вместо него самого.
    //`loadReference: []` — дочитывать ссылки САМОГО референта нас не просили;
    //без него requestItems тянет весь первый уровень (тот же приём, что в
    //NsgDataItem.loadAllReferents).
    var referent = NsgDataClient.client.getNewObject(T);
    var cmp = NsgCompare();
    cmp.add(name: referent.primaryKeyField, value: id);
    var filter = NsgDataRequestParams(compare: cmp);
    var request = NsgDataRequest<T>();
    var loaded = await request.requestItems(filter: filter, loadReference: []);

    //Из кэша, а не из ответа: там объект уже слит с ранее известным экземпляром,
    //и вызывающий получит тот же instance, что и синхронный геттер (#1548 —
    //читаем с учётом наследования, объект мог лечь в ведро наследника).
    var item = NsgDataClient.client.getItemsFromCacheTyped<T>(id, allowNull: true) ?? loaded.firstOrNull;
    //Объекта может не быть и после запроса: удалён, скрыт правами, чужой id.
    //Отдаём пустышку — тот же контракт, что у getReferent. Здесь стоял `item!`,
    //и этот случай падал `Null check operator used on a null value`, не называя
    //ни типа, ни поля.
    return item ?? NsgDataClient.client.getNewObject(T) as T;
  }

  @override
  String formattedValue(NsgDataItem item, String locale) {
    var referent = (getReferent(item, allowNull: true));
    if (referent == null) {
      return item[name].toString();
    } else {
      return referent.toString();
    }
  }

  @override
  int compareTo(NsgDataItem a, NsgDataItem b) {
    var valueA = a.getFieldValue(name).toString();
    var valueB = b.getFieldValue(name).toString();
    return valueA.compareTo(valueB);
  }
}
