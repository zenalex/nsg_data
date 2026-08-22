import 'package:get/get.dart';
import 'package:nsg_data/nsg_data_itemList.dart';
import 'nsg_data.dart';
import 'nsg_data_paramList.dart';

class NsgDataClient {
  NsgDataClient._();

  static NsgDataClient client = NsgDataClient._();

  final _registeredItems = <String, NsgDataItem>{};
  final _registeredServerNames = <String, String>{};
  final _fieldList = <String, NsgFieldList>{};
  final _predefinedList = <String, List<String>>{};
  final _paramList = <String, NsgParamList>{};
  final _itemList = <String, NsgItemList>{};

  ///Количество зарегистрированных типов данных в провайдере
  int get registeredDataItemsCount => _registeredItems.keys.length;

  ///Количество зарегистрированных типов данных в провайдере
  List<NsgDataItem> get registeredDataItems => _registeredItems.values.toList();

  void registerDataItem(NsgDataItem item, {NsgDataProvider? remoteProvider}) {
    if (remoteProvider != null) item.remoteProvider = remoteProvider;
    _registeredItems[item.runtimeType.toString()] = item;
    _registeredServerNames[item.typeName] = item.runtimeType.toString();
    _fieldList[item.runtimeType.toString()] = NsgFieldList();
    _predefinedList[item.runtimeType.toString()] = <String>[];
    // Появился новый тип — карта наследников устарела. Регистрация идёт на
    // старте и один раз, так что сброс ничего не стоит.
    _subtypeBuckets.clear();
    item.initialize();
  }

  ///Re-initializing enums. For example for changing localization
  void initializeEnums() {
    // #1000: на раннем boot / в async-окне Get.context бывает null, а геттеры enum
    // резолвят локализованные имена через AppLocalizations.of(Get.context!) → Null
    // check operator on null. Имена уже выставлены при регистрации (registerDataItem);
    // здесь это лишь ре-инициализация под смену локали — пропускаем, переразрешится
    // при следующем вызове, когда контекст готов.
    if (Get.context == null) return;
    for (var item in _registeredItems.values) {
      if (item is NsgEnum) {
        item.initialize();
      }
    }
  }

  ///Вернуть все зарегистрированные классы данных по tyoeName
  ///Внимание!!! В релизной веб версии типы данных изменят свои названия из-за обфускации
  List<String> getAllRegisteredTypes() {
    return _registeredItems.keys.toList();
  }

  ///Вернуть все зарегистрированные классы данных по именам серверных классов
  ///Необходимо, чтобы защититься от обфускации
  List<String> getAllRegisteredServerNames() {
    return _registeredServerNames.keys.toList();
  }

  NsgFieldList getFieldList(Type itemType) {
    if (_registeredItems.containsKey(itemType.toString())) {
      return _fieldList[itemType.toString()]!;
    }
    throw ArgumentError('getFieldList: $itemType not found');
  }

  List<String> getPredefinedList(Type itemType) {
    if (_registeredItems.containsKey(itemType.toString())) {
      return _predefinedList[itemType.toString()]!;
    }
    throw ArgumentError('getPredefinedList: $itemType not found');
  }

  bool isRegistered(Type type) {
    return (_registeredItems.containsKey(type.toString()));
  }

  bool isRegisteredByName(String typeName) {
    return (_registeredItems.containsKey(typeName));
  }

  bool isRegisteredByServerName(String typeName) {
    return (_registeredServerNames.containsKey(typeName) && _registeredItems.containsKey(_registeredServerNames[typeName]));
  }

  NsgDataItem getNewObject(Type type) {
    return getNewObjectByTypeName(type.toString());
  }

  NsgDataItem getNewObjectByTypeName(String typeName) {
    assert(_registeredItems.containsKey(typeName), typeName);
    return _registeredItems[typeName]!.getNewObject();
  }

  Type getTypeByName(String typeName) {
    assert(_registeredItems.containsKey(typeName), 'typeName = $typeName');
    return _registeredItems[typeName]!.runtimeType;
  }

  Type getTypeByServerName(String typeName) {
    assert(_registeredServerNames.containsKey(typeName), 'typeName = $typeName');
    return _registeredItems[_registeredServerNames[typeName]]!.runtimeType;
  }

  NsgParamList getParamList(Type itemType) {
    if (!_paramList.containsKey(itemType.toString())) {
      _paramList[itemType.toString()] = NsgParamList();
    }
    return _paramList[itemType.toString()]!;
  }

  void addItemsToCache({List<NsgDataItem?>? items, String? tag = ''}) {
    if (items == null || items.isEmpty) return;
    var time = DateTime.now();
    var cache = _getItemsCacheByType(items[0].runtimeType);
    for (var item in items) {
      cache!.add(item: item!, time: time, tag: tag);
    }
  }

  NsgItemList? _getItemsCacheByType(Type type) {
    if (!_itemList.containsKey(type.toString())) {
      _itemList[type.toString()] = NsgItemList();
    }
    return _itemList[type.toString()];
  }

  /// Имена вёдер зарегистрированных наследников [T] (без самого [T]).
  ///
  /// Строится сканированием реестра: он хранит по экземпляру на тип, а `is T`
  /// с настоящим параметром типа работает и без reflection, которого во
  /// Flutter нет. Результат запоминается — сканирование идёт один раз на тип,
  /// а не на каждый промах.
  final _subtypeBuckets = <String, List<String>>{};

  List<String> _subtypeBucketNames<T extends NsgDataItem>() {
    final key = T.toString();
    final cached = _subtypeBuckets[key];
    if (cached != null) return cached;
    final names = <String>[];
    for (final registered in _registeredItems.values) {
      final name = registered.runtimeType.toString();
      if (name == key) continue;
      if (registered is T) names.add(name);
    }
    _subtypeBuckets[key] = names;
    return names;
  }

  /// Чтение кэша, знающее про наследование (#1548).
  ///
  /// Ведро выбирается при записи по ФАКТИЧЕСКОМУ типу объекта
  /// ([addItemsToCache]), а ссылка читает по ОБЪЯВЛЕННОМУ — `T` из
  /// `NsgDataReferenceField<T>`. Пока это один и тот же тип, всё сходится.
  /// Расходятся они там, где `_fromJsonList` подменил объект наследником по
  /// `extensionTypeField`: фото приезжает как `ImageFileItem` и ложится в его
  /// ведро, а `photoId` объявлен ссылкой на `FileItem` и смотрит в ведро
  /// `FileItem` — там пусто.
  ///
  /// Промах при этом ПОСТОЯННЫЙ: «ремонт» в `loadAllReferents` идёт тем же
  /// путём и снова кладёт в ведро наследника. То есть такие объекты не
  /// кэшируются вовсе и перезапрашиваются при каждом обращении.
  ///
  /// Поэтому при промахе в ведре [T] заглядываем в вёдра его наследников.
  /// Выбран именно фолбэк на чтении, а не запись в оба ведра: объект остаётся
  /// в одном экземпляре, и два ведра не могут разъехаться молча. Цена — только
  /// на промахе, в удачном пути не платим ничего.
  T? getItemsFromCacheTyped<T extends NsgDataItem>(String id, {bool allowNull = false}) {
    var item = _getItemsCacheByType(T)!.getItem(id);
    if (item == null) {
      for (final bucket in _subtypeBucketNames<T>()) {
        item = _itemList[bucket]?.getItem(id);
        if (item != null) break;
      }
    }
    // Приведение безопасно: смотрим только ведро самого T и вёдра тех типов,
    // чей зарегистрированный экземпляр прошёл `is T`.
    return item == null ? (allowNull ? null : getNewObject(T) as T) : item.dataItem as T;
  }

  NsgDataItem? getItemsFromCache(Type type, String id, {bool allowNull = false}) {
    var cache = _getItemsCacheByType(type)!;
    var item = cache.getItem(id);
    // if (!allowNull && item == null) {
    //   // для отладки
    //   print('STOP!!!');
    // }
    // assert(allowNull || item != null, 'type=$type, id = $id');
    return item == null ? (allowNull ? null : NsgDataClient.client.getNewObject(type)) : item.dataItem;
  }

  /// Получить все ID кэшированных объектов указанного типа
  List<String> getCachedItemIds(Type type) {
    var cache = _getItemsCacheByType(type);
    if (cache == null || cache.items.isEmpty) {
      return [];
    }
    return cache.items.keys.toList();
  }

  NsgDataBaseReferenceField? getReferentFieldByFullPath(Type dataType, String fullPath) {
    var splitedPath = fullPath.split('.');
    var type = dataType;
    var fieldFound = false;
    NsgDataBaseReferenceField? foundField;
    for (var i = 0; i < splitedPath.length; i++) {
      fieldFound = false;
      var fieldList = NsgDataClient.client.getFieldList(type);
      if (fieldList.fields.containsKey(splitedPath[i])) {
        var field = fieldList.fields[splitedPath[i]];
        if (field is NsgDataReferenceField) {
          type = field.referentType;
          foundField = field;
          fieldFound = true;
        } else if (field is NsgDataReferenceListField) {
          type = field.referentElementType;
          fieldFound = true;
          foundField = field;
        }
      }
    }
    if (fieldFound) {
      return foundField;
    } else {
      return null;
    }
  }
}
