import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:retry/retry.dart';

class NsgDataRequest<T extends NsgDataItem> {
  List<T> items = <T>[];

  ///Сколько всего элементов, удовлетворяющих условиям поиска, есть на сервере
  int? totalCount;
  Type dataItemType;
  FutureOr<bool> Function(Exception)? retryIf;
  NsgDataStorageType storageType;

  NsgDataRequest({this.dataItemType = NsgDataItem, this.storageType = NsgDataStorageType.server}) {
    if (dataItemType == NsgDataItem) dataItemType = T;
  }

  ///Код ошибки «ответ не той формы». Номер из того же непротокольного ряда,
  ///что 1 (нет связи) и 2 (таймаут) в NsgApiError, — HTTP-статус здесь не при
  ///чём: сервер ответил 200, не той формой (NSG-SOFT/futbolista-tasks#1922).
  static const int _codeMalformedResponse = 3;

  ///Максимум символов тела ответа, попадающих в текст ошибки. Начала хватает,
  ///чтобы опознать источник (страница captive-portal, HTML-заглушка шлюза,
  ///текст ошибки), а всё тело в сообщении об ошибке — и мусор, и утечка данных.
  static const int _bodyPreviewLimit = 200;

  ///Однострочное начало значения для сообщения об ошибке.
  static String _preview(dynamic value) {
    final text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= _bodyPreviewLimit) return text;
    return '${text.substring(0, _bodyPreviewLimit)}...';
  }

  ///Ответ пришёл не той формы: на месте JSON-массива объектов оказалось что-то
  ///другое. Раньше такой ответ заворачивался в список и падал голым
  ///`TypeError: type 'String' is not a subtype of type 'Map<String, dynamic>'`
  ///в `_fromJsonList` — без адреса запроса, без типа данных и без единого
  ///признака, что именно приехало (NSG-SOFT/futbolista-tasks#1922, GT-4675).
  ///
  ///`TypeError` — это `Error`, а не `Exception`: его не ловит ни `retry`, ни
  ///`on Exception` в `NsgBaseController._requestItems`. Экран не получал статус
  ///ошибки и оставался в бесконечной загрузке, а в телеметрию улетало событие
  ///уровня fatal, неотличимое от любого другого промаха каста в пакете.
  NsgApiException _malformedResponse({required String url, required String what, required dynamic got}) {
    final cause = got is NsgApiException ? ' Ошибка запроса: ${got.error.code} ${got.error.message}.' : '';
    return NsgApiException(NsgApiError(
      code: _codeMalformedResponse,
      message: 'Сервер вернул ответ неожиданной формы. $what '
          'Запрос: $url. Тип данных: ${NsgDataClient.client.getNewObject(dataItemType).typeName}. '
          'Тип ответа: ${got.runtimeType}.$cause Начало ответа: ${_preview(got)}',
    ));
  }

  List<NsgDataItem> _fromJsonList(List<dynamic> maps, {String url = ''}) {
    var items = <T>[];
    for (var i = 0; i < maps.length; i++) {
      final m = maps[i];
      //Элемент массива обязан быть объектом. Сервер, отдавший массив строк
      //(или массив с null), до #1922 ронял тот же безымянный TypeError.
      if (m is! Map<String, dynamic>) {
        throw _malformedResponse(url: url, what: 'Элемент [$i] массива — не объект.', got: m);
      }
      var elem = NsgDataClient.client.getNewObject(dataItemType);
      elem.fromJson(m);
      if (elem.allowExtend) {
        var extTypeName = elem[elem.extensionTypeField].toString();
        if (extTypeName.isNotEmpty && extTypeName != elem.typeName) {
          try {
            elem = NsgDataClient.client.getNewObject(NsgDataClient.client.getTypeByServerName(extTypeName));
            elem.fromJson(m);
          } on AssertionError catch (ex) {
            if (ex.message == extTypeName) {
              debugPrint('Unknown type $extTypeName');
            } else {
              rethrow;
            }
          }
        }
      }
      elem.isReadFromServer = storageType == NsgDataStorageType.server;
      // elem.state = NsgDataItemState.fill;
      items.add(elem as T);
    }
    return items;
  }

  ///Запрос одного объекта. Для запроса списка объектов используйте requestItems
  ///Выполняет запрос по стандартному методу, заданному в бъекте
  ///Можно перекрыть для изменения логики запроса
  ///filter = доп. фильтр, особенное внимание следует обратить на его сво-во compare
  ///autoAuthorize - переход на авторизацию, если будет получен отказ в доступе
  ///tag - доп признак для кэширования
  ///loadReference - список полей для дочитывания, можно передавать через точку, null - будут дочитаны все поля
  ///                ссылочного типа первого уровн, пустой массив - не будет дочитано ничего
  ///                Обратите внимание, по умолчанию дочитываются все поля, что может негативно сказаться на производительности
  ///function - url вызываемого метода, если не задан, будет взят url данного объекта по умолчанию
  ///method - метод запроса. Рекомендуем всегда использовать POST из-за отсутствия ограничений на передаваемые параметры
  ///postData - передаваемые данные. Не рекомендуется использовать напрямую
  ///autoRepeate - повторять ли запрос в случае ошибки связи
  ///autoRepeateCount - максимальное количество повторов
  ///retryIf - функция, вызываемая перед каждым повторным вызовом. Если вернет false, повторы будут остановлены
  ///onRetry - функция, вызываемая при каждом повторе запроса
  Future<List<T>> requestItems({
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    List<String>? loadReference,
    String function = '',
    String method = 'GET',
    dynamic postData,
    bool autoRepeate = true,
    int autoRepeateCount = 10,
    FutureOr<bool> Function(Exception)? userRetryIf,
    FutureOr<void> Function(Exception)? userOnRetry,
    NsgCancelToken? cancelToken,
  }) async {
    if (storageType == NsgDataStorageType.server) {
      retryIf = userRetryIf;
      if (autoRepeate) {
        final r = RetryOptions(maxAttempts: autoRepeateCount, maxDelay: const Duration(seconds: 15));
        return await r.retry(
          () => _requestItems(
            filter: filter,
            tag: tag,
            loadReference: loadReference,
            function: function,
            method: method,
            postData: postData,
            externalCancelToken: cancelToken,
          ),
          retryIf: _retryIfInternal,
          onRetry: userOnRetry,
        );
        // onRetry: (error) => _updateStatusError(error.toString()));
      } else {
        return await _requestItems(
          filter: filter,
          tag: tag,
          loadReference: loadReference,
          function: function,
          method: method,
          postData: postData,
          externalCancelToken: cancelToken,
        );
      }
    } else {
      return await _requestItemsFromDb(filter: filter, tag: tag, loadReference: loadReference);
    }
  }

  ///Токен текущего запроса. При повторном вызове запроса, предыдущий запрос будет отменен автоматически
  ///В будущем, планируется добавить механизм, уведомляющий сервер об отмене запроса с целью прекращения подготовки ненужных данных
  NsgCancelToken? cancelToken;
  Future<List<T>> _requestItems({
    NsgDataRequestParams? filter,
    String tag = '',
    List<String>? loadReference,
    String function = '',
    String method = 'GET',
    Map<String, dynamic>? postData,
    NsgCancelToken? externalCancelToken,
  }) async {
    if (cancelToken != null && externalCancelToken != cancelToken && !cancelToken!.isCalceled) {
      cancelToken!.calcel();
    }
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);
    if (dataItem.remoteProvider.usesServerpod) {
      return await _requestItemsFromServerpod(
        dataItem: dataItem,
        filter: filter,
        tag: tag,
        loadReference: loadReference,
        function: function,
      );
    }
    var filterMap = <String, dynamic>{};

    //Добавление в запрос имен полей, требующих дочитывания
    if (loadReference == null && dataItem.loadReferenceDefault != null) {
      loadReference = dataItem.loadReferenceDefault;
    }
    if (loadReference == null) {
      loadReference = [];
      loadReference = addAllReferences(dataItem.runtimeType);
    }
    filter ??= NsgDataRequestParams();

    filter.referenceList ??= loadReference;

    method = 'POST';
    if (method == 'GET') {
      filterMap = filter.toJson();
    } else {
      postData ??= {};
      postData.addAll(filter.toJson());
    }

    if (function == '') {
      function = dataItem.remoteProvider.serverUri + dataItem.apiRequestItems;
    } else {
      function = dataItem.remoteProvider.serverUri + function;
    }
    var url = function;
    //Кто и с каким набором ссылок грузил объект. Без этого промах дочитывания
    //неадресуем — см. NsgFieldUsage.noteRequest.
    NsgFieldUsage.noteRequest(dataItem.typeName, url, filter.referenceList);
    var response = await dataItem.remoteProvider.baseRequestList(
      function: url,
      headers: dataItem.remoteProvider.getAuthorizationHeader(),
      url: url,
      method: method,
      params: filterMap,
      postData: postData,
      cancelToken: cancelToken,
    );
    items = <T>[];
    try {
      if (response == '' || response == null) {
      } else {
        if (response is Map) {
          items = (await loadDataAndReferences(response, filter.referenceList!, tag, filter: filter)).cast();
        } else {
          //Здесь стояло `if (response is! List) response = <dynamic>[response];`
          //— заворачивание скаляра в список из одного элемента. Успешно
          //разобраться такой список не мог никогда: скаляр не Map, и
          //следующая же строка падала кастом. На проде сюда приезжала HTML-
          //страница (перехват соединения на Wi-Fi), и пользователь получал
          //вечную загрузку вместо ошибки — NSG-SOFT/futbolista-tasks#1922.
          if (response is! List) {
            throw _malformedResponse(url: url, what: 'Ожидался массив объектов.', got: response);
          }
          items = _fromJsonList(response, url: url).cast();
          NsgDataClient.client.addItemsToCache(items: items, tag: tag);

          //Check referent field list
          await loadAllReferents(items, filter.referenceList, tag: tag);
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    // Здесь стоял `debugPrint("items length = ${items.length}")` — безусловный,
    // на КАЖДОМ запросе, и debugPrint работает в релизе тоже.
    //
    // Диагностической ценности у строки нет: она не называет ни тип данных, ни
    // запрос. Зато Sentry подбирает print'ы как хлебные крошки, и на проде эта
    // строка выедала весь их бюджет: в событии «nsg: read of unrequested field»
    // (GT-4057) из 100 крошек 90+ были «items length = N», а полезные —
    // навигация и события экрана — из окна вытеснены.
    //
    // Это ломало разбор той самой диагностики недочитанных ссылок: понять, какой
    // запрос загрузил объект, было не из чего.
    return items;
  }

  Future<List<T>> _requestItemsFromServerpod({
    required NsgDataItem dataItem,
    NsgDataRequestParams? filter,
    String tag = '',
    List<String>? loadReference,
    String function = '',
  }) async {
    loadReference ??= dataItem.loadReferenceDefault ?? addAllReferences(dataItem.runtimeType);
    filter ??= NsgDataRequestParams();
    filter.referenceList ??= loadReference;

    final context = NsgServerpodRequestContext(
      provider: dataItem.remoteProvider,
      prototype: dataItem,
      dataItemType: dataItemType,
      filter: filter,
      loadReference: filter.referenceList ?? const <String>[],
      tag: tag,
      function: function,
    );
    final response = await _runServerpodReadWithRetry(
      () async => await dataItem.resolvedServerpodAdapter.fetchItems(context),
    );

    dynamic rawItems = response;
    if (response is NsgServerpodListResult) {
      totalCount = response.totalCount;
      rawItems = response.items;
    }
    if (rawItems is! List) {
      rawItems = rawItems == null ? <dynamic>[] : <dynamic>[rawItems];
    }

    items = <T>[];
    for (final rawItem in rawItems) {
      final elem = NsgDataClient.client.getNewObject(dataItemType);
      elem.fromServerpodValue(rawItem);
      elem.isReadFromServer = true;
      items.add(elem as T);
    }
    NsgDataClient.client.addItemsToCache(items: items, tag: tag);
    await loadAllReferents(items, filter.referenceList, tag: tag);
    return items;
  }

  Future<dynamic> _runServerpodReadWithRetry(Future<dynamic> Function() action) async {
    final retry = RetryOptions(
      maxAttempts: 3,
      delayFactor: const Duration(milliseconds: 300),
      maxDelay: const Duration(milliseconds: 1800),
    );
    try {
      return await retry.retry(
        action,
        retryIf: (e) async => _shouldRetryServerpodRead(e),
        onRetry: (e) => debugPrint('Retry serverpod read for $dataItemType: $e'),
      );
    } catch (e) {
      if (_shouldRetryServerpodRead(e)) {
        final localized = _localizedServerpodReadErrorMessage(e);
        debugPrint('Serverpod read failed after retries for $dataItemType: $e');
        throw Exception(localized);
      }
      rethrow;
    }
  }

  Future<List<T>> _requestItemsFromDb({NsgDataRequestParams? filter, String tag = '', List<String>? loadReference}) async {
    var dataItem = NsgDataClient.client.getNewObject(dataItemType);

    //Добавление в запрос имен полей, требующих дочитывания
    if (loadReference == null && dataItem.loadReferenceDefault != null) {
      loadReference = dataItem.loadReferenceDefault;
    }
    if (loadReference == null) {
      loadReference = [];
      loadReference = addAllReferences(dataItem.runtimeType);
    }
    filter ??= NsgDataRequestParams();
    filter.referenceList = loadReference;

    items = (await NsgLocalDb.instance.requestItems(dataItem, filter)).cast();

    try {
      NsgDataClient.client.addItemsToCache(items: items, tag: tag);

      //Check referent field list
      await loadAllReferents(items, loadReference, tag: tag, readTableParts: true);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return items;
  }

  ///Список полей, которые были явно запрошены у сервера (fieldsToRead и/или neededFields).
  ///null — сужения не было, читались все поля.
  Set<String>? _requestedFieldNames(NsgDataRequestParams? filter) {
    if (filter == null) return null;
    final names = <String>{};
    final legacy = filter.fieldsToRead;
    if (legacy != null && legacy.isNotEmpty) {
      names.addAll(legacy.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    final needed = filter.neededFields;
    if (needed != null && needed.isNotEmpty) {
      names.addAll(needed.map((e) => e.trim()).where((e) => e.isNotEmpty));
      //Точечный путь `teamHomeId.name` сужает референт, но саму колонку `teamHomeId`
      //сервер при этом читает — он выводит её из пути сам (NarrowRefFields). Клиент
      //обязан выводить так же, иначе пометит ссылку непрочитанной, хотя она пришла:
      //чтение вернёт значение (оно выигрывает у пометки), а вот слияние в кэше уже
      //посчитает поле пустым. Сейчас не стреляет только потому, что вызывающий
      //перечисляет и плоское поле тоже, — но это его удача, а не свойство кода.
      names.addAll(needed.map((e) => e.trim().split('.').first).where((e) => e.isNotEmpty));
    }
    return names.isEmpty ? null : names;
  }

  ///#1383: поля, запрошенные у ДОЧИТЫВАЕМЫХ объектов: тип -> имена полей.
  ///
  ///Точечная запись в neededFields (`teamHomeId.name`) сужает не основной объект, а референт,
  ///и сервер по ней отдаёт урезанные объекты. Здесь считается то же самое на клиенте, чтобы
  ///непришедшие поля были помечены пустыми, а не молча отдавали defaultValue.
  ///
  ///Тип определяется проходом по пути от корня (поле-ссылка -> её referentElementType), а не
  ///поиском по глобальному реестру: путь и так задаёт тип однозначно, а реестр потребовал бы
  ///уникальности имён.
  ///
  ///Тип, до которого ведёт хотя бы один путь БЕЗ точечных полей, из карты исключается: по
  ///такому пути сервер пришлёт объект целиком, и разметка пустых была бы ложной.
  Map<Type, Set<String>> _requestedReferentFields(NsgDataRequestParams? filter, List<String> loadReference) {
    final needed = filter?.neededFields;
    if (needed == null || needed.isEmpty) return const {};

    final result = <Type, Set<String>>{};
    for (final entry in needed) {
      final path = entry.trim().split('.');
      if (path.length < 2) continue;
      final type = _typeByPath(path.sublist(0, path.length - 1));
      if (type == null) continue;
      (result[type] ??= <String>{}).add(path.last);
    }
    if (result.isEmpty) return const {};

    //Пути дочитывания без сужения: по ним приедет весь объект
    for (final reference in loadReference) {
      final path = reference.trim().split('.');
      final type = _typeByPath(path);
      if (type == null || !result.containsKey(type)) continue;
      final prefix = '${path.join('.')}.';
      if (!needed.any((e) => e.trim().startsWith(prefix))) result.remove(type);
    }
    return result;
  }

  ///Тип объекта, до которого ведёт путь ссылочных полей от dataItemType. null, если путь
  ///обрывается (не ссылка, неизвестное поле).
  Type? _typeByPath(List<String> path) {
    Type current = dataItemType;
    for (final segment in path) {
      final field = NsgDataClient.client.getFieldList(current).fields[segment];
      if (field is NsgDataReferenceField) {
        current = field.referentElementType;
      } else if (field is NsgDataReferenceListField) {
        current = field.referentElementType;
      } else {
        return null;
      }
    }
    return current;
  }

  ///Загружает данные из response, представляющего из себя Map.
  ///основные объекты лежат в results, кэшируемые по названию полей основного объекта
  Future<List> loadDataAndReferences(Map response, List<String> loadReference, String tag, {NsgDataRequestParams? filter}) async {
    var maps = response as Map<String, dynamic>;
    //Новые основные элементы
    var newItems = <NsgDataItem>[];
    //Все новые элементы, включая дочитанные объекты для поиска строк табличных частей
    var allItems = <NsgDataItem>[];
    var useCache = (filter == null || filter.fieldsToRead == null || filter.fieldsToRead!.isEmpty);
    //#1394: сужение может быть задано и устаревшим fieldsToRead, и neededFields.
    //Разметка emptyFields раньше учитывала только первый, поэтому на neededFields
    //обращение к незапрошенному полю молча отдавало defaultValue даже в debug.
    final requestedFields = _requestedFieldNames(filter);
    //#1383: то же для дочитываемых объектов - они и есть основная часть ответа
    final requestedReferentFields = _requestedReferentFields(filter, loadReference);
    maps.forEach((name, data) {
      if (name == '_results_' || name == 'results') {
        newItems = _fromJsonList(data);
        allItems.addAll(newItems);
        if (newItems.isNotEmpty && requestedFields != null) {
          //Проставить полям из списка признак того, что она пустые - не прочитаны с БД
          final fields = newItems.first.fieldList.fields;
          for (var fieldName in fields.keys) {
            if (requestedFields.contains(fieldName)) continue;
            //Табличные части - не колонки строки, их наличие определяется не сужением
            //полей, а дочитыванием (referenceList/readTableParts). Пометить их пустыми
            //означало бы ложную тревогу на каждом запросе с сужением.
            if (fields[fieldName] is NsgDataReferenceListField) continue;
            for (var item in newItems) {
              item.setFieldEmpty(fieldName);
            }
          }
        }
        //А если там уже есть такой же элемент с ранее дочитанными полями?
        if (useCache) {
          NsgDataClient.client.addItemsToCache(items: newItems, tag: tag);
        }
      } else if (name == 'resultsCount') {
        totalCount = int.tryParse(data);
      } else {
        // var foundField = NsgDataClient.client.getReferentFieldByFullPath(dataItemType, name);
        // if (foundField != null) {
        //   var refItems = <NsgDataItem>[];
        //   data.forEach((m) {
        //     if (foundField is NsgDataUntypedReferenceField) {
        //       // var elem = NsgDataClient.client.getNewObject(foundField.referentElementType!);
        //       // elem.fromJson(m as Map<String, dynamic>);
        //       // refItems.add(elem);
        //     } else {
        //       var elem = NsgDataClient.client.getNewObject(foundField.referentElementType);
        //       elem.fromJson(m as Map<String, dynamic>);
        //       refItems.add(elem);
        //     }
        //   });
        //   allItems.addAll(refItems);
        //   if (foundField is NsgDataReferenceListField) {
        //     for (var tabItem in refItems) {
        //       var ownerItem = allItems.firstWhere((e) => tabItem.ownerId == e.id);
        //       foundField.addRow(ownerItem, tabItem);
        //     }
        //   } else {
        //     if (useCache) {
        //       NsgDataClient.client.addItemsToCache(items: refItems, tag: tag);
        //     }
        //   }
        // } else
        {
          if (name.isNotEmpty) {
            name = name.replaceRange(0, 1, name.substring(0, 1).toUpperCase());
          }
          if (NsgDataClient.client.isRegisteredByServerName(name)) {
            var refItems = <NsgDataItem>[];
            final refType = NsgDataClient.client.getTypeByServerName(name);
            final refRequested = requestedReferentFields[refType];
            data.forEach((m) {
              var elem = NsgDataClient.client.getNewObject(refType);
              elem.fromJson(m as Map<String, dynamic>);
              elem.state = NsgDataItemState.fill;
              if (refRequested != null) {
                for (var fieldName in elem.fieldList.fields.keys) {
                  if (refRequested.contains(fieldName)) continue;
                  //Табличные части приезжают дочитыванием, а не колонкой - см. основной объект
                  if (elem.fieldList.fields[fieldName] is NsgDataReferenceListField) continue;
                  elem.setFieldEmpty(fieldName);
                }
              }
              refItems.add(elem);
            });
            if (useCache) {
              NsgDataClient.client.addItemsToCache(items: refItems, tag: tag);
            }
          } else {
            debugPrint('ERROR: $dataItemType.$name not found');
          }
        }
      }
    });
    await loadAllReferents(newItems, loadReference, tag: tag);
    return newItems;
  }

  ///Добавить в вписок все ссылочные типа объекта типа type
  ///Если среди полей будет табличная часть, ее ссылочные поля также будут
  ///добавлены в список через имяТаблицы.имяПоля
  static List<String> addAllReferences(Type type, {List<String> exceptFields = const []}) {
    List<String> loadReference = [];
    var allFields = NsgDataClient.client.getFieldList(type);
    for (var field in allFields.fields.values) {
      if (exceptFields.contains(field.name)) {
        continue;
      }
      if ((field is NsgDataReferenceField || field is NsgDataReferenceListField) && field.name != NsgDataItem.nameOwnerId) {
        loadReference.add(field.name);
      }
      if (field is NsgDataReferenceListField) {
        var tableRefereces = addAllReferences(field.referentElementType);
        for (var item in tableRefereces) {
          loadReference.add('${field.name}.$item');
        }
      }
    }
    return loadReference;
  }

  ///Оснорвной метод запроса данных
  ///Выполняет запрос по стандартному методу, заданному в объекте
  ///Можно перекрыть для изменения логики запроса
  ///filter = доп. фильтр, особенное внимание следует обратить на его сво-во compare
  ///autoAuthorize - переход на авторизацию, если будет получен отказ в доступе
  ///tag - доп признак для кэширования
  ///loadReference - список полей для дочитывания, можно передавать через точку, null - будут дочитаны все поля
  ///                ссылочного типа первого уровн, пустой массив - не будет дочитано ничего
  ///                Обратите внимание, по умолчанию дочитываются все поля, что может негативно сказаться на производительности
  ///function - url вызываемого метода, если не задан, будет взят url данного объекта по умолчанию
  ///method - метод запроса. Рекомендуем всегда использовать POST из-за отсутствия ограничений на передаваемые параметры
  ///addCount - в фильтр будет добавлено ограничение считываемых объектов до одного
  ///postData - передаваемые данные. Не рекомендуется использовать напрямую
  ///autoRepeate - повторять ли запрос в случае ошибки связи
  ///autoRepeateCount - максимальное количество повторов
  ///retryIf - функция, вызываемая перед каждым повторным вызовом. Если вернет false, повторы будут остановлены
  ///onRetry - функция, вызываемая при каждом повторе запроса
  ///requestRegime - режим запроса. Позволяет определить для чего загружаются данные при перекрытии логики данного метода
  Future<T> requestItem({
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    List<String>? loadReference,
    String function = '',
    String method = 'GET',
    bool addCount = true,
    dynamic postData,
    bool autoRepeate = false,
    int autoRepeateCount = 1000,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
    NsgCancelToken? cancelToken,
  }) async {
    NsgDataRequestParams? newFilter;
    if (addCount) {
      if (filter == null) {
        newFilter = NsgDataRequestParams(count: 1);
      } else {
        newFilter = NsgDataRequestParams(
          top: filter.top,
          count: 1,
          params: filter.params,
          sorting: filter.sorting,
          referenceList: filter.referenceList,
          compare: filter.compare,
          showDeletedObjects: filter.showDeletedObjects,
        );
      }
    }
    var data = await requestItems(
      filter: newFilter,
      autoAuthorize: autoAuthorize,
      tag: tag,
      loadReference: loadReference,
      function: function,
      method: method,
      postData: postData,
      autoRepeate: autoRepeate,
      autoRepeateCount: autoRepeateCount,
      userRetryIf: retryIf,
      userOnRetry: onRetry,
      cancelToken: cancelToken,
    );
    if (data.isEmpty) {
      return NsgDataClient.client.getNewObject(dataItemType) as T;
    }
    return data[0];
  }

  Future loadAllReferents(List<NsgDataItem> items, List<String>? loadReference, {String tag = '', bool readTableParts = true}) async {
    if (items.isEmpty || loadReference == null || loadReference.isEmpty) {
      return;
    }
    try {
      for (var fieldName in loadReference) {
        var splitedName = fieldName.split('.');
        var field = NsgDataClient.client.getReferentFieldByFullPath(items[0].runtimeType, splitedName[0]);
        if (field is! NsgDataBaseReferenceField) continue;
        var refList = <String>[];
        var refItems = <NsgDataItem>[];
        var checkItems = <NsgDataItem>[];

        if (field is NsgDataReferenceField && field is! NsgDataUntypedReferenceField) {
          for (var item in items) {
            var checkedItem = field.getReferent(item, allowNull: true);
            if (checkedItem == null) {
              var fieldValue = item.getFieldValue(splitedName[0]).toString();
              if (fieldValue != '' && !fieldValue.contains(Guid.Empty) && (!refList.contains(fieldValue))) {
                refList.add(fieldValue);
              }
            } else {
              checkItems.add(checkedItem);
            }
          }

          if (refList.isNotEmpty) {
            var request = NsgDataRequest(dataItemType: field.referentElementType);
            var cmp = NsgCompare();
            cmp.add(
              name: NsgDataClient.client.getNewObject(field.referentElementType).primaryKeyField,
              value: refList,
              comparisonOperator: NsgComparisonOperator.inList,
            );
            var filter = NsgDataRequestParams(compare: cmp);
            //print('field.referentElementType ${field.referentElementType}');
            if (storageType == NsgDataStorageType.server) {
              refItems = await request.requestItems(filter: filter, loadReference: []);
            } else {
              refItems = await NsgLocalDb.instance.requestItems(NsgDataClient.client.getNewObject(field.referentElementType), filter);
            }
            checkItems.addAll(refItems);
          }
        } else if (field is NsgDataUntypedReferenceField) {
          var sortedFields = <String, List<String>>{};
          for (var item in items) {
            var checkedItem = field.getReferent(item, allowNull: true);
            if (checkedItem == null) {
              var splittedFieldValue = item.getFieldValue(splitedName[0]).toString().split('.');

              if (splittedFieldValue.length == 2 && !splittedFieldValue[0].contains(Guid.Empty)) {
                if (!sortedFields.containsKey(splittedFieldValue[1])) {
                  sortedFields[splittedFieldValue[1]] = <String>[];
                }
                var refList = sortedFields[splittedFieldValue[1]];
                if (!refList!.contains(splittedFieldValue[0])) {
                  refList.add(splittedFieldValue[0]);
                }
              }
            } else {
              checkItems.add(checkedItem);
            }
          }

          if (sortedFields.isNotEmpty) {
            for (var typeName in sortedFields.keys) {
              var refList = sortedFields[typeName];
              var refType = NsgDataClient.client.getTypeByServerName(typeName);
              var request = NsgDataRequest(dataItemType: refType);
              var cmp = NsgCompare();
              cmp.add(name: NsgDataClient.client.getNewObject(refType).primaryKeyField, value: refList, comparisonOperator: NsgComparisonOperator.inList);
              var filter = NsgDataRequestParams(compare: cmp);
              if (storageType == NsgDataStorageType.server) {
                refItems = await request.requestItems(filter: filter, loadReference: []);
              } else {
                refItems = await NsgLocalDb.instance.requestItems(NsgDataClient.client.getNewObject(refType), filter);
              }
              checkItems.addAll(refItems);
            }
          }
        } else if (field is NsgDataReferenceListField) {
          for (var item in items) {
            var fieldValue = item.getFieldValue(splitedName[0]) as List<NsgDataItem>;
            if (readTableParts && storageType == NsgDataStorageType.local) {
              if (fieldValue.isNotEmpty) {
                var cmp = NsgCompare();
                var ids = <String>[];
                for (var e in fieldValue) {
                  ids.add(e.id);
                }
                cmp.add(name: fieldValue[0].primaryKeyField, value: ids, comparisonOperator: NsgComparisonOperator.inList);
                var request = NsgDataRequest(dataItemType: fieldValue[0].runtimeType, storageType: NsgDataStorageType.local);
                var rows = await request.requestItems(filter: NsgDataRequestParams(compare: cmp));
                for (var row in rows) {
                  var tr = fieldValue.firstWhereOrNull((e) => e.id == row.id);
                  if (tr != null) {
                    tr.copyFieldValues(row);
                  }
                }
              }
            }
            refItems.addAll(fieldValue);
            checkItems.addAll(fieldValue);
          }
        }

        if (splitedName.length > 1 && checkItems.isNotEmpty) {
          splitedName.removeAt(0);
          //Данные для проверки на дочитывание необходимо рассортировать по типам данных на случай если они получены по нетипизированной ссылке
          var mapData = <Type, List<NsgDataItem>>{};
          for (var item in checkItems) {
            List<NsgDataItem>? list = mapData[item.runtimeType];
            if (list == null) {
              list = <NsgDataItem>[];
              mapData[item.runtimeType] = list;
            }
            list.add(item);
          }
          for (var key in mapData.keys) {
            await loadAllReferents(mapData[key]!, [splitedName.join('.')], tag: tag);
          }
        }
      }
    } catch (ex) {
      debugPrint('ERROR LAR-375: dataType: $dataItemType, $ex');
    }
  }

  FutureOr<bool> _retryIfInternal(Exception ex) async {
    //400 - код ошибки сервера, не предполагающий повторного запроса данных
    if (ex is NsgApiException && (ex.error.code == 400 || ex.error.code == 401 || ex.error.code == 500)) {
      return false;
    }
    //Ответ не той формы повтором не лечится: тело уже получено, и получено
    //целиком. Повторять его 10 раз с паузой до 15 секунд — значит держать
    //экран в загрузке минутами вместо того, чтобы показать ошибку сразу.
    //До #1922 здесь падал TypeError, который retry не ловил вовсе, — быстрый
    //отказ и есть поведение, которое надо сохранить.
    if (ex is NsgApiException && ex.error.code == _codeMalformedResponse) {
      return false;
    }
    if (retryIf != null) return (await retryIf!(ex));
    return true;
  }

  bool _shouldRetryServerpodRead(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('accessdenied') ||
        text.contains('validation') ||
        text.contains('conflict') ||
        text.contains('permission') ||
        text.contains('statuscode = 400') ||
        text.contains('statuscode = 401') ||
        text.contains('statuscode = 403') ||
        text.contains('statuscode = 404')) {
      return false;
    }
    return text.contains('socketexception') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('statuscode = -1') ||
        text.contains('connection closed') ||
        text.contains('connection terminated');
  }

  String _localizedServerpodReadErrorMessage(Object error) {
    final languageCode = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    final text = error.toString().toLowerCase();
    final isRu = languageCode.startsWith('ru');
    if (text.contains('timed out') || text.contains('timeout')) {
      return isRu
          ? 'Превышено время ожидания ответа сервера. Проверьте соединение и повторите попытку.'
          : 'The server response timed out. Check your connection and try again.';
    }
    return isRu
        ? 'Сервер временно недоступен или соединение нестабильно. Повторите попытку через несколько секунд.'
        : 'The server is temporarily unavailable or the connection is unstable. Please try again in a few seconds.';
  }
}
