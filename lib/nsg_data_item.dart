import 'package:nsg_data/nsg_data.dart';
import 'nsg_data_paramList.dart';

class NsgDataItem {
  static String nameOwnerId = 'ownerId';

  List<String>? loadReferenceDefault;

  ///Get API path for request Items
  String get apiRequestItems {
    throw Exception('api Request Items is not overrided');
  }

  ///Get API path for posting Items
  String get apiPostItems => apiRequestItems + '/Post';

  ///Get API path for delete Items
  String get apiDeleteItems => apiRequestItems + '/Delete';

  ///Имя поля для фильтрации в контроллере по периоду
  ///Используется, например, в NsgListPage
  ///Если не задано, то считается, что фильтрация по периоду запрещена
  String get periodFieldName => '';

  ///Возвращает уникальный идентификатор владельца
  String get id => '';

  set id(String value) {
    assert(primaryKeyField.isNotEmpty);
    this[primaryKeyField] = value;
  }

  ///Возвращает идентификатор владельца
  ///Используется для привязки строк к табличной части
  String get ownerId => '';

  ///Устанавливает идентификатор владельца
  ///Используется для привязки строк к табличной части
  set ownerId(String value) => setFieldValue(nameOwnerId, value);

  ///Признак того: что для создания элемента должно производится на серверной стороне
  ///У объекта на сервере будет вызван метод Create
  bool get createOnServer => false;

  ///Время загрузки элемента с сервера. Используется для сравнения элементов: а также,
  ///для удаления устаревших элементов из кэша
  int loadTime = 0;

  ///Текущее состаяние объекта (новый, сохранен и т.п.)
  NsgDataItemState state = NsgDataItemState.unknown;

  NsgDataStorageType storageType = NsgDataStorageType.server;

  String get typeName => runtimeType.toString();

  ///Чтение полей объекта из JSON
  void fromJson(Map<String, dynamic> json) {
    json.forEach((name, jsonValue) {
      if (fieldList.fields.containsKey(name)) {
        setFieldValue(name, jsonValue);
      }
    });
    if (json.containsKey('state')) {
      state = NsgDataItemState.values[json['state']];
    }
    loadTime = DateTime.now().microsecondsSinceEpoch;
  }

  ///Запись полей объекта в JSON
  Map<String, dynamic> toJson({List<String> excludeFields = const []}) {
    var map = <String, dynamic>{};
    for (var name in fieldList.fields.keys) {
      if (excludeFields.contains(name)) continue;
      var value = fieldList.fields[name];
      map[name] = value!.convertToJson(getFieldValue(name));
    }
    map['state'] = state.index;
    return map;
  }

  ///Создание нового экземпляра объекта данного типа
  ///Метод необходим из-за отсутствии рефлексии и невозможности создания объекта по его типу
  NsgDataItem getNewObject() {
    throw Exception('getNewObject for type {runtimeType} is not defined');
  }

  ///Инициализация объекта. Создание всех полей. Выполняется один раз при запуске программы при построении всех объектов
  void initialize() {
    throw Exception('initialize for type {runtimeType} is not defined');
  }

  ///Возвращает список полей объекта.
  ///Внимание! это единый список для всех объектов данного типа
  NsgFieldList get fieldList => NsgDataClient.client.getFieldList(runtimeType);

  ///Список дополнительных параметров
  NsgParamList get paramList => NsgDataClient.client.getParamList(runtimeType);

  ///Значения полей объекта
  ///Так как поля обшие, значения храняться в отдельном объекте для экономии памяти
  ///Хранятся только значения, отличные от значений по умолчанию
  final NsgFieldValues fieldValues = NsgFieldValues();

  ///Добавление ногого поля в объект
  ///Вызывается при инициализации
  void addField(NsgDataField field, {bool primaryKey = false, String? presentation}) {
    var name = field.name;
    assert(!fieldList.fields.containsKey(name));
    fieldList.fields[name] = field;
    if (primaryKey) {
      assert(primaryKeyField == '');
      primaryKeyField = name;
    }
    if (presentation != null) field.presentation = presentation;
  }

  ///Получить поле объекта по его имени
  NsgDataField getField(String name) {
    assert(fieldList.fields.containsKey(name), 'containsKey >> $name');
    return fieldList.fields[name]!;
  }

  ///Приверка является ли поле ссылкой на другой объект (ссылочный тип)
  bool isReferenceField(String name) {
    return getField(name) is NsgDataBaseReferenceField;
  }

  ///Получить значение поля объекта по имени поля
  ///Если значение не присваивалось, то будет возвращено значение по умолчению, если
  ///allowNullValue == false или null, если allowNullValue == true
  dynamic getFieldValue(String name, {bool allowNullValue = false}) {
    if (fieldValues.fields.containsKey(name)) {
      return fieldValues.fields[name];
    } else {
      //Проверка на наличие поля в списке полей объекта
      assert(fieldList.fields.containsKey(name), name);
      //Проверка не является ли поле пустым (умышленно не читалось из БД, следовательно, нельзя брать значение из него)
      assert(!fieldValues.emptyFields.contains(name));
      if (allowNullValue) return null;
      return fieldList.fields[name]!.defaultValue;
    }
  }

  ///Установить значение поля
  void setFieldValue(String name, dynamic value) {
    //TODO: убрать этот метод, присваивать значения в setValue полей
    if (!fieldList.fields.containsKey(name)) {
      assert(fieldList.fields.containsKey(name), 'object $runtimeType does not contains field $name');
    }
    var field = getField(name);
    if (field is NsgDataDoubleField) {
      field.setValue(fieldValues, value);
      return;
    }
    if (value is NsgEnum) {
      value = value.value;
    } else if (value is NsgDataItem) {
      if (fieldList.fields[name] is NsgDataUntypedReferenceField) {
        value = '${value.getFieldValue(value.primaryKeyField)}.${value.typeName}';
      } else {
        value = value.getFieldValue(value.primaryKeyField);
      }
    } else if (value is DateTime) {
      value = value.toIso8601String();
    } else if (value is double) {
      var field = getField(name);
      if (field is NsgDataDoubleField) {
        value = value.nsgRoundToDouble(field.maxDecimalPlaces);
      }
    } else if (name != primaryKeyField) {
      if (value is String) {
        var field = getField(name);
        if (field is NsgDataStringField && value.length > field.maxLength && field.maxLength != 0) {
          value = value.toString().substring(0, field.maxLength);
        } else if (field is NsgDataDoubleField) {
          //TODO: такое впечатление, что весь это метод надо заменить на данную строку.
          //Отложил это изменение, чтобы все не сломать
          field.setValue(fieldValues, value);
          return;
        }
      }
    }
    fieldValues.setValue(this, name, value);
  }

  ///Пометить поле пустым, т.е. что оно не загружалось из БД
  void setFieldEmpty(String name) {
    if (!fieldList.fields.containsKey(name)) {
      assert(fieldList.fields.containsKey(name), 'object $runtimeType does not contains field $name');
    }
    fieldValues.setEmpty(this, name);
  }

  // ignore: constant_identifier_names
  static const String _PARAM_REMOTE_PROVIDER = 'RemoteProvider';
  NsgDataProvider get remoteProvider {
    if (paramList.params.containsKey(_PARAM_REMOTE_PROVIDER)) {
      return paramList.params[_PARAM_REMOTE_PROVIDER] as NsgDataProvider;
    } else {
      throw Exception('RemoteProvider not set');
    }
  }

  set remoteProvider(NsgDataProvider? value) => paramList.params[_PARAM_REMOTE_PROVIDER] = value;

  ///В случае ссылочного поля позвращает объект, на который ссылается данное поле
  T getReferent<T extends NsgDataItem?>(String name) {
    assert(fieldList.fields.containsKey(name));
    var field = fieldList.fields[name]!;
    if (field is NsgDataReferenceField) {
      return field.getReferent(this) as T;
    } else if (field is NsgDataEnumReferenceField) {
      return field.getReferent(this) as T;
    }
    throw Exception('field $name is not ReferencedField');
  }

  ///В случае ссылочного поля позвращает объект, на который ссылается данное поле
  ///Допускает возврат null, если ссылка не задана
  T? getReferentOrNull<T extends NsgDataItem?>(String name) {
    assert(fieldList.fields.containsKey(name));
    var field = fieldList.fields[name]!;
    if (field is NsgDataReferenceField) {
      return field.getReferent(this, allowNull: true) as T;
    } else if (field is NsgDataEnumReferenceField) {
      return field.getReferent(this) as T;
    } else if (field is NsgDataReferenceListField) {
      // Пока решил возвращать null, т.к. иначе непонятно что возвращать
      return null;
    }
    throw Exception('field $name is not ReferencedField');
  }

  ///В случае ссылочного поля позвращает объект, на который ссылается данное поле. Если поле не прочитано из БД, читает его асинхронно
  Future<T> getReferentAsync<T extends NsgDataItem>(String name, {bool useCache = true}) async {
    assert(fieldValues.fields.containsKey(name));
    var field = fieldList.fields[name]!;
    assert(field is NsgDataReferenceField);
    var dataItem = await ((field as NsgDataReferenceField).getReferentAsync(this, useCache: useCache));
    return dataItem as T;
  }

  // ignore: constant_identifier_names
  static const String _PRIMARY_KEY_FIELD = 'PrimaryKeyField';

  ///Возвращает значение ключегого поля (обычно Guid)
  String get primaryKeyField {
    if (paramList.params.containsKey(_PRIMARY_KEY_FIELD)) {
      return paramList.params[_PRIMARY_KEY_FIELD].toString();
    } else {
      return '';
    }
  }

  ///Устанавливает значение ключевого поля (обычно Guid)
  set primaryKeyField(String value) => paramList.params[_PRIMARY_KEY_FIELD] = value;

  ///Возвращает список всех полей ссылочных типов
  List<String> getAllReferenceFields() {
    var list = <String>[];
    for (var name in fieldValues.fields.keys) {
      var field = fieldList.fields[name];
      if (field is NsgDataReferenceField) {
        list.add(name);
      }
    }

    return list;
  }

  ///Проверяет является ли объект пустым
  ///Внимание! Проверка осуществляется только по значению ключевого поля
  ///Объект будет считалься пустым, если это значение не задано или является нулевым Guid
  bool get isEmpty {
    var guidString = id;
    return guidString == Guid.Empty || guidString.isEmpty;
  }

  ///Проверяет что объект не пустой
  ///Подробности см. в описании свойства isEmpty
  bool get isNotEmpty => !isEmpty;
  @override
  bool operator ==(Object other) => other is NsgDataItem && equal(other);
  bool equal(NsgDataItem other) {
    return hashCode == other.hashCode;
    // if (primaryKeyField == '') return hashCode == other.hashCode;
    // return (getFieldValue(primaryKeyField) == other.getFieldValue(primaryKeyField) && loadTime == other.loadTime);
  }

  @override
  int get hashCode {
    if (primaryKeyField == '') return super.hashCode;
    //return (getFieldValue(primaryKeyField).toString() + loadTime.toString()).hashCode;
    return (getFieldValue(primaryKeyField).toString()).hashCode;
  }

  operator [](String name) => getFieldValue(name);
  operator []=(String name, dynamic value) => setFieldValue(name, value);

  ///Сохранение объекта в БД
  ///В случае успеха, поля текущего объекта будут заполнены полями объекта из БД
  Future post() async {
    if (storageType == NsgDataStorageType.server) {
      var p = NsgDataPost(dataItemType: runtimeType);
      p.itemsToPost = <NsgDataItem>[this];
      var newItem = await p.postItem();
      if (newItem != null) {
        copyFieldValues(newItem);
        state = newItem.state;
      }
    } else {
      await NsgLocalDb.instance.postItems([this]);
    }
  }

  ///Copy all fields values from oldItem to this
  void copyFieldValues(NsgDataItem oldItem, {bool cloneAsCopy = false}) {
    fieldList.fields.forEach((key, value) {
      if (fieldList.fields[key] is NsgDataReferenceListField) {
        var newTable = NsgDataTable(owner: this, fieldName: key);
        var curTable = NsgDataTable(owner: oldItem, fieldName: key);
        newTable.clear();
        for (var row in curTable.rows) {
          var newRow = row.clone(cloneAsCopy: cloneAsCopy);
          if (cloneAsCopy) {
            newRow.copyRecordFill();
          }
          newTable.addRow(newRow);
        }
      } else {
        setFieldValue(key, oldItem.getFieldValue(key));
      }
    });
  }

  ///Create new object with same filelds values
  ///cloneAsCopy - после копирования подменить id объектов и вызвать метод заполнения после копирования
  NsgDataItem clone({bool cloneAsCopy = false}) {
    var newItem = getNewObject();
    newItem.copyFieldValues(this, cloneAsCopy: cloneAsCopy);
    newItem.loadTime = loadTime;
    newItem.state = cloneAsCopy ? NsgDataItemState.create : state;
    newItem.storageType = storageType;
    if (cloneAsCopy) {
      newItem.copyRecordFill();
    }
    return newItem;
  }

  ///Новая запись в БД
  ///По факту: создает новый Guid ключевому полю
  ///Если ключевое поле заполнено не нулевым Guid, будет сгенерирована ошибка
  void newRecord() {
    assert(id.isNotEmpty && id != Guid.Empty);
    setFieldValue(primaryKeyField, Guid.newGuid());
    state = NsgDataItemState.create;
  }

  ///Заполнение полей объекта при создании нового
  void newRecordFill() {}

  ///Заполнение полей объекта при создании копии
  void copyRecordFill() {
    id = Guid.newGuid();
    state = NsgDataItemState.create;
  }

  ///Контроллер ранных, который будет использоваться по-умолчанию для подбора значений в полях ввода
  ///Может быть перекрыт. Рекомендуется использовать механизм Get.find
  NsgBaseController? get defaultController => null;

  ///Форма списка для подбора объектов по умолчанию
  ///Используется в NsgInput, если не задана явно
  String? get defaultListPage => null;

  ///Список полей, по которым производится текстовый поиск при вводе строки поиска пользователем в фильтре
  ///По умолчанию, поиск идет по всем полям, за исключением нетипизированных ссылок, дат и перечислений
  ///Также из поиска исключено ключевое поле (там практически всегда Guid)
  List<String> get searchFieldList {
    var list = <String>[];
    for (var fieldName in fieldList.fields.keys) {
      var field = getField(fieldName);
      if (field.name == primaryKeyField || field is NsgDataUntypedReferenceField || field is NsgDataEnumReferenceField || field is NsgDataDateField) {
        continue;
      }
      list.add(fieldName);
    }
    return list;
  }

  ///Проверка является ли поле с именем fieldName обязательным к заполнению пользователем
  bool isFieldRequired(String fieldName) {
    return false;
  }

  ///Метод проверки правильности запорлненности всех полей объекта перед его сохранением
  ///Если не перекрыт, проверяет заполненнойсть полей, помеченных как обязательные.
  ///Поле считается пустым, если его значение равно значению по умолчанию для этого поля
  NsgValidateResult validateFieldValues() {
    var answer = NsgValidateResult();
    for (var fieldName in fieldList.fields.keys) {
      if (isFieldRequired(fieldName)) {
        if (fieldValues.fields[fieldName] == fieldList.fields[fieldName]!.defaultValue) {
          var fieldPresentation = fieldList.fields[fieldName]!.presentation;
          if (fieldPresentation.isEmpty) {
            fieldPresentation = fieldName;
          }
          answer.isValid = false;
          answer.fieldsWithError[fieldName] = 'Не заполнено обязательное поле $fieldPresentation';
        }
      }
    }
    return answer;
  }

  NsgDataField? getFieldByFullPath(String fullPath) {
    var splitedPath = fullPath.split('.');
    var fieldFound = false;
    NsgDataField? foundField;
    Type type = runtimeType;
    for (var i = 0; i < splitedPath.length; i++) {
      fieldFound = false;
      if (type == NsgDataItem) {
        break;
      }
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
        } else {
          type = NsgDataItem;
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

  //TODO: ДОДЕЛАТЬ!!!
  dynamic getFieldValueByFullPath(String fullPath) {
    var splitedPath = fullPath.split('.');
    var fieldFound = false;
    NsgDataField? foundField;
    Type type = runtimeType;
    for (var i = 0; i < splitedPath.length; i++) {
      fieldFound = false;
      if (type == NsgDataItem) {
        break;
      }
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
        } else {
          type = NsgDataItem;
          fieldFound = true;
          foundField = field;
        }
      }
    }
    if (fieldFound) {
      return this[foundField!.name];
    } else {
      return null;
    }
  }
}
