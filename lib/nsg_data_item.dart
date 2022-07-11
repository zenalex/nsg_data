import 'package:nsg_data/nsg_data.dart';
import 'helpers/nsg_data_guid.dart';
import 'nsg_data_paramList.dart';

class NsgDataItem {
  List<String>? loadReferenceDefault;

  ///Get API path for request Items
  String get apiRequestItems {
    throw Exception('api Request Items is not overrided');
  }

  ///Get API path for posting Items
  String get apiPostItems => apiRequestItems + '/Post';

  ///Имя поля для фильтрации в контроллере по периоду
  ///Используется, например, в NsgListPage
  ///Если не задано, то считается, что фильтрация по периоду запрещена
  String get periodFieldName => '';

  ///Возвращает уникальный идентификатор владельца
  String get id => '';

  ///Возвращает идентификатор владельца
  ///Используется для привязки строк к табличной части
  String get ownerId => '';

  ///Признак того: что для создания элемента должно производится на серверной стороне
  ///У объекта на сервере будет вызван метод Create
  bool get createOnServer => false;

  ///Чтение полей объекта из JSON
  void fromJson(Map<String, dynamic> json) {
    json.forEach((name, jsonValue) {
      if (fieldList.fields.containsKey(name)) {
        setFieldValue(name, jsonValue);
      }
    });
  }

  ///Запись полей объекта в JSON
  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    fieldList.fields.forEach((name, value) {
      map[name] = value.convertToJson(getFieldValue(name));
    });
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
  NsgFieldList get fieldList => NsgDataClient.client.getFieldList(this.runtimeType);

  ///Список дополнительных параметров
  NsgParamList get paramList => NsgDataClient.client.getParamList(this.runtimeType);

  ///Значения полей объекта
  ///Так как поля обшие, значения храняться в отдельном объекте для экономии памяти
  ///Хранятся только значения, отличные от значений по умолчанию
  final NsgFieldValues fieldValues = NsgFieldValues();

  ///Добавление ногого поля в объект
  ///Вызывается при инициализации
  void addField(NsgDataField field, {bool primaryKey = false}) {
    var name = field.name;
    assert(!fieldList.fields.containsKey(name));
    fieldList.fields[name] = field;
    if (primaryKey) {
      assert(primaryKeyField == '');
      primaryKeyField = name;
    }
  }

  ///Получить поле объекта по его имени
  NsgDataField getField(String name) {
    assert(fieldList.fields.containsKey(name));
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
    if (!fieldList.fields.containsKey(name)) {
      print('object $runtimeType does not contains field $name');
      assert(fieldList.fields.containsKey(name));
    }
    if (value is NsgEnum) {
      value = value.value;
    }
    if (value is NsgDataItem) {
      value = value.getFieldValue(value.primaryKeyField);
    }
    if (value is DateTime) {
      value = value.toIso8601String();
    }
    if (name != primaryKeyField) {
      if (value is String) {
        var field = this.getField(name);
        if (field is NsgDataStringField && value.length > field.maxLength && field.maxLength != 0) {
          value = value.toString().substring(0, field.maxLength);
        }
      } else if (value is double) {
        var field = this.getField(name);
        if (field is NsgDataDoubleField) {
          value = num.parse(value.toStringAsFixed(field.maxDecimalPlaces));
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

  ///В случае ссылочного поля позвращает объект, на который ссылается данное поле. Если поле не прочитано из БД, читает его асинхронно
  Future<T> getReferentAsync<T extends NsgDataItem>(String name, {bool useCache = true}) async {
    assert(fieldValues.fields.containsKey(name));
    var field = fieldList.fields[name]!;
    assert(field is NsgDataReferenceField);
    var dataItem = await ((field as NsgDataReferenceField).getReferentAsync(this, useCache: useCache));
    return dataItem as T;
  }

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
    fieldValues.fields.keys.forEach((name) {
      var field = fieldList.fields[name];
      if (field is NsgDataReferenceField) {
        list.add(name);
      }
    });

    return list;
  }

  ///Проверяет является ли объект пустым
  ///Внимание! Проверка осуществляется только по значению ключевого поля
  ///Объект будет считалься пустым, если это значение не задано или является нулевым Guid
  bool get isEmpty {
    var guidString = getFieldValue(primaryKeyField).toString();
    return guidString == Guid.Empty || guidString.isEmpty;
  }

  ///Проверяет что объект не пустой
  ///Подробности см. в описании свойства isEmpty
  bool get isNotEmpty => !isEmpty;
  @override
  bool operator ==(Object other) => other is NsgDataItem && equal(other);
  bool equal(NsgDataItem other) {
    if (other.runtimeType.toString() == runtimeType.toString()) {
      if (primaryKeyField == '') return hashCode == other.hashCode;
      return (getFieldValue(primaryKeyField) == other.getFieldValue(primaryKeyField));
    }
    return false;
  }

  @override
  int get hashCode {
    if (primaryKeyField == '') return super.hashCode;
    return getFieldValue(primaryKeyField).hashCode;
  }

  operator [](String name) => getFieldValue(name);
  operator []=(String name, dynamic value) => setFieldValue(name, value);

  ///Сохранение объекта в БД
  ///В случае успеха, поля текущего объекта будут заполнены полями объекта из БД
  Future post() async {
    var p = NsgDataPost(dataItemType: runtimeType);
    p.itemsToPost = <NsgDataItem>[this];
    var newItem = await p.postItem();
    if (newItem != null) {
      copyFieldValues(newItem);
    }
  }

  ///Copy all fields values from newItem to this
  void copyFieldValues(NsgDataItem newItem) {
    fieldList.fields.forEach((key, value) {
      setFieldValue(key, newItem.getFieldValue(key));
    });
  }

  ///Create new object with same filelds values
  NsgDataItem clone() {
    var newItem = getNewObject();
    newItem.copyFieldValues(this);
    return newItem;
  }

  ///Новая запись в БД
  ///По факту: создает новый Guid ключевому полю
  ///Если ключевое поле заполнено не нулевым Guid, будет сгенерирована ошибка
  void newRecord() {
    assert(id.isNotEmpty && id != Guid.Empty);
    setFieldValue(primaryKeyField, Guid.newGuid());
  }

  ///Контроллер ранных, который будет использоваться по-умолчанию для подбора значений в полях ввода
  ///Может быть перекрыт. Рекомендуется использовать механизм Get.find
  NsgBaseController? get defaultController => null;

  ///Форма списка для подбора объектов по умолчанию
  ///Используется в NsgInput, если не задана явно
  String? get defaultListPage => null;
}
