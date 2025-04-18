import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:retry/retry.dart';

class NsgSimpleRequest<T extends Object> {
  List<T> items = <T>[];

  ///Сколько всего элементов, удовлетворяющих условиям поиска, есть на сервере
  int? totalCount;
  FutureOr<bool> Function(Exception)? _retryIf;

  NsgSimpleRequest();

  Future<List<T>> requestItems({
    required NsgDataProvider provider,
    required String function,
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    String method = 'GET',
    dynamic postData,
    bool autoRepeate = false,
    int autoRepeateCount = 1000,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
    NsgCancelToken? cancelToken,
  }) async {
    _retryIf = retryIf;
    if (autoRepeate) {
      final r = RetryOptions(maxAttempts: autoRepeateCount);
      return await r.retry(
          () => _requestItems(
              provider: provider,
              filter: filter,
              autoAuthorize: autoAuthorize,
              tag: tag,
              function: function,
              method: method,
              postData: postData,
              externalCancelToken: cancelToken),
          retryIf: _retryIfInternal,
          onRetry: onRetry);
      // onRetry: (error) => _updateStatusError(error.toString()));
    } else {
      return await _requestItems(
          provider: provider,
          filter: filter,
          autoAuthorize: autoAuthorize,
          tag: tag,
          function: function,
          method: method,
          postData: postData,
          externalCancelToken: cancelToken);
    }
  }

  FutureOr<bool> _retryIfInternal(Exception ex) async {
    //400 - код ошибки сервера, не предполагающий повторного запроса данных
    if (ex is NsgApiException && (ex.error.code == 400 || ex.error.code == 401 || ex.error.code == 500)) {
      return false;
    }
    if (_retryIf != null) return (await _retryIf!(ex));
    return true;
  }

  ///Токен текущего запроса. При повторном вызове запроса, предыдущий запрос будет отменен автоматически
  ///В будущем, планируется добавить механизм, уведомляющий сервер об отмене запраса с целью прекращения подготовки ненужных данных
  NsgCancelToken? cancelToken;
  Future<List<T>> _requestItems({
    required NsgDataProvider provider,
    required String function,
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
    String method = 'GET',
    Map<String, dynamic>? postData,
    NsgCancelToken? externalCancelToken,
  }) async {
    if (cancelToken != null && externalCancelToken != cancelToken && !cancelToken!.isCalceled) {
      cancelToken!.calcel();
    }
    cancelToken ??= NsgCancelToken();
    var filterMap = <String, dynamic>{};

    filter ??= NsgDataRequestParams();

    method = 'POST';
    if (method == 'GET') {
      filterMap = filter.toJson();
    } else {
      postData ??= {};
      postData.addAll(filter.toJson());
    }

    var url = provider.serverUri + function;
    var response = await provider.baseRequestList(
        function: url, headers: provider.getAuthorizationHeader(), url: url, method: method, params: filterMap, postData: postData, cancelToken: cancelToken);
    items = <T>[];
    try {
      if (response == '' || response == null) {
      } else {
        if (response is Map) {
          var maps = response as Map<String, dynamic>;
          maps.forEach((name, data) {
            if (name == '_results_' || name == 'results') {
              assert(data is List);
              items = (data as List).cast();
            }
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return items;
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
  Future<T?> requestItem({
    required NsgDataProvider provider,
    required String function,
    NsgDataRequestParams? filter,
    bool autoAuthorize = true,
    String tag = '',
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
            top: filter.top, count: 1, params: filter.params, sorting: filter.sorting, referenceList: filter.referenceList, compare: filter.compare);
      }
    }
    var data = await requestItems(
      provider: provider,
      filter: newFilter,
      autoAuthorize: autoAuthorize,
      tag: tag,
      function: function,
      method: method,
      postData: postData,
      autoRepeate: autoRepeate,
      autoRepeateCount: autoRepeateCount,
      retryIf: retryIf,
      onRetry: onRetry,
      cancelToken: cancelToken,
    );
    if (data.isEmpty) {
      return null;
    }
    return data[0];
  }
}
