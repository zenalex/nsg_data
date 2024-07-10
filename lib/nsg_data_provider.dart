import 'dart:async';
import 'dart:io';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:nsg_controls/widgets/nsg_error_widget.dart';
import 'package:nsg_data/controllers/nsgBaseController.dart';
import 'package:nsg_data/nsgApiException.dart';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'authorize/nsg_login_model.dart';
import 'authorize/nsg_login_params.dart';
import 'authorize/nsg_login_response.dart';
import 'controllers/nsg_cancel_token.dart';
import 'nsgDataApiError.dart';

class NsgDataProvider {
  ///Token saved after authorization
  String? token = '';

  ///server uri (i.e. https://your_server.com:port)
  String serverUri = 'http://192.168.1.20:5073';

  ///authorization path without serverUri (i.e. 'Api/Auth/Login')
  String authorizationApi = 'Api/Auth/Login';

  ///provider name
  String? name;

  ///application name
  ///Для проверки на сервере для избежания ошибок подключения к другому серверу
  String applicationName;

  ///Версия приложения. Проверяется на сервере для требования или рекомендации обновления
  String applicationVersion;

  ///Используется ли стандартная система авторизации NSG для получения и хранения токена пользователя
  bool useNsgAuthorization = true;

  ///Если true, то будет выполнен метод connect для соединения с сервером.
  ///Может использоваться для отложенной связи с сервером
  bool allowConnect;

  ///Провайдер инициализирован. Для избежания повторной инициализации
  bool _initialized = false;

  ///Используется анонимный токен. Пользователь не авторизован на сервере
  bool isAnonymous = true;

  ///Программа работает в режиме отладки
  bool isDebug = kDebugMode;

  ///Авторизация обязательна. Если нет, работа может вестись в анонимном режиме
  bool loginRequired = true;

  ///Сохранять ли токен локально на устройстве
  bool saveToken = true;

  ///Сохранять ли токен локально на в браузере по умолчанию.
  ///Фактически определяется параметром saveToken
  bool saveTokenWebDefaultTrue = false;

  ///Время запроса sms для ограничения времени переодичности запросов
  DateTime? smsRequestedTime;

  ///Номер телефона под которым авторизовался пользователь
  String? phoneNumber;

  ///Firebase token for this device
  String firebaseToken;

  ///Функция, вызываемая при необходимости отображения окна входа
  final Future Function()? eventOpenLoginPage;

  ///milliseconds
  int requestDuration = 120000;
  int connectDuration = 15000;

  late NsgLoginParams Function() widgetParams;

  static String defaultSecurityCode = 'security';

  NsgDataProvider(
      {this.name,
      required this.applicationName,
      this.serverUri = '', //https://servername.me:1234
      this.authorizationApi = 'Api/Auth',
      this.useNsgAuthorization = true,
      this.allowConnect = true,
      required this.firebaseToken,
      required this.applicationVersion,
      NsgLoginParams Function()? widgetLoginParams,
      this.eventOpenLoginPage}) {
    widgetParams = widgetLoginParams ?? () => NsgLoginParams();
  }

  ///Initialization. Load saved token if useNsgAuthorization == true
  Future initialize() async {
    if (_initialized) return;
    if (useNsgAuthorization) {
      var _prefs = await SharedPreferences.getInstance();
      if (_prefs.containsKey(applicationName)) {
        token = _prefs.getString(applicationName);
        isAnonymous = false;
      }
      if (kIsWeb && !saveTokenWebDefaultTrue) {
        // || (!Platform.isAndroid && !Platform.isIOS)) {
        saveToken = false;
      } else {
        saveToken = true;
      }
    }
    _initialized = true;
  }

  Future<dynamic> baseRequestList(
      {final String? function,
      final Map<String, dynamic>? params,
      final dynamic postData,
      final Map<String, String?>? headers,
      final String? url,
      //TODO: сделать настраиваемым параметром
      //final int timeout = timeout,
      final String method = 'GET',
      final NsgCancelToken? cancelToken,
      FutureOr<void> Function(Exception)? onRetry}) async {
    final _dio = Dio(BaseOptions(
      headers: headers,
      method: method,
      responseType: ResponseType.json,
      contentType: 'application/json',
      connectTimeout: Duration(milliseconds: connectDuration),
      receiveTimeout: Duration(milliseconds: requestDuration),
    ));

    //Response<List<dynamic>> response;
    late Response<dynamic> response;

    try {
      if (!kIsWeb) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
      //TODO: сделать генерацию метода запроса GET/POST
      var method2 = 'POST';
      var dioCancelToken = cancelToken?.dioCancelToken;
      if (method2 == 'GET') {
        response = await _dio.get(url!, queryParameters: params, cancelToken: dioCancelToken);
      } else if (method2 == 'POST') {
        response = await _dio.post(url!, queryParameters: params, data: postData, cancelToken: dioCancelToken);
      }
      if (isDebug) {
        debugPrint('HTTP STATUS: ${response.statusCode}');
      }

      return response.data;
    } on DioException catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ?? ''}');
      if (e.response?.statusCode == 400) {
        //400 - Сервер отказался предоставлять данные. Повторять запрос бессмыслено
        throw NsgApiException(NsgApiError(code: 400, message: e.response?.data, errorType: e.type));
      }
      if (e.response?.statusCode == 401) {
        throw NsgApiException(NsgApiError(code: 401, message: 'Authorization error', errorType: e.type));
      }
      if (e.response?.statusCode == 500) {
        var msg = 'Ошибка 500';
        if (e.response!.data is Map && (e.response!.data as Map).containsKey('message')) {
          var msgParts = e.response!.data['message'].split('---> ');
          //TODO: в нулевом параметре функция, вызвавшая ишибку - надо где-то показывать
          msg = msgParts.last;
        }
        throw NsgApiException(NsgApiError(code: 500, message: msg, errorType: e.type));
      } else if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        throw NsgApiException(NsgApiError(code: 2, message: 'Истекло время ожидания получения или отправки данных', errorType: e.type));
      } else {
        debugPrint('###');
        debugPrint('### Error: ${e.error}');
        debugPrint('###');
        throw NsgApiException(NsgApiError(code: 1, message: 'Internet connection error', errorType: e.type));
      }
    } catch (e) {
      debugPrint('network error. function: $function, error: $e');
      return NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<Map<String, dynamic>?> baseRequest(
      {final String? function,
      final Map<String, dynamic>? params,
      final Map<String, String?>? headers,
      final String? url,
      //final int timeout = 15000,
      final String method = 'GET',
      bool autoRepeate = false,
      int autoRepeateCount = 1000,
      FutureOr<bool> Function(Exception)? retryIf,
      FutureOr<void> Function(Exception)? onRetry}) async {
    if (autoRepeate) {
      final r = RetryOptions(maxAttempts: autoRepeateCount);
      return await r.retry(
          () => _baseRequest(
              function: function,
              params: params,
              headers: headers,
              url: url,
              //timeout: timeout,
              method: method),
          retryIf: retryIf,
          onRetry: onRetry);
      // onRetry: (error) => _updateStatusError(error.toString()));
    } else {
      return await _baseRequest(
          function: function,
          params: params,
          headers: headers,
          url: url,
          //timeout: timeout,
          method: method);
    }
  }

  Future<Map<String, dynamic>?> _baseRequest({
    final String? function,
    final Map<String, dynamic>? params,
    final Map<String, String?>? headers,
    final String? url,
    //final int timeout = 15000,
    final String method = 'GET',
  }) async {
    final _dio = Dio(BaseOptions(
      headers: headers,
      method: method,
      responseType: ResponseType.json,
      contentType: 'application/json',
      // connectTimeout: timeout,
      // receiveTimeout: timeout,
    ));

    late Response<Map<String, dynamic>> response;

    try {
      //BrowserHttpClientAdapter
      if (!kIsWeb) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
      if (method == 'GET') {
        response = await _dio.get(url!, queryParameters: params);
      } else if (method == 'POST') {
        response = await _dio.post(url!, data: params);
      }
      // if (isDebug) {
      //   print('HTTP STATUS: ${response.statusCode}');
      //   print(response.data);
      // }
      var curData = response.data;
      return curData;
    } on DioException catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ?? ''}');
      throw NsgApiException(NsgApiError(code: e.response?.statusCode, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      debugPrint('network error. function: $function, error: $e');
      throw NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<Image> imageRequest({
    final String? function,
    final Map<String, dynamic>? params,
    final Map<String, String?>? headers,
    final String? url,
    //final int timeout = 15000,
    final bool debug = false,
    final String method = 'GET',
  }) async {
    final _dio = Dio(BaseOptions(
        headers: headers,
        method: method,
        responseType: ResponseType.json,
        contentType: 'application/json',
        connectTimeout: Duration(milliseconds: connectDuration),
        receiveTimeout: Duration(milliseconds: requestDuration)));

    late Response<Uint8List> response;

    try {
      if (!kIsWeb) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
      if (method == 'GET') {
        response = await _dio.get<Uint8List>(url!, queryParameters: params, options: Options(responseType: ResponseType.bytes));
      } else if (method == 'POST') {
        response = await _dio.post<Uint8List>(url!, data: params, options: Options(responseType: ResponseType.bytes));
      }
      if (debug) {
        debugPrint('HTTP STATUS: ${response.statusCode}');
        //print(response.data);
      }

      return Image.memory(response.data!);
    } on DioException catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ?? ''}');
      throw NsgApiException(NsgApiError(code: 1, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      debugPrint('network error. function: $function, error: $e');
      throw NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<bool> internetConnected() async {
    return true;
    //return await Connectivity().checkConnectivity() != ConnectivityResult.none;
  }

  ///Connect to server
  ///If error will be occured, NsgApiException will be generated
  Future connect(NsgBaseController controller) async {
    if (!_initialized) await initialize();
    var onRetry = controller.onRetry;

    if (useNsgAuthorization && allowConnect && serverUri.isNotEmpty) {
      var checkResult = await _checkVersion(onRetry);
      if (checkResult == 2) {
        NsgErrorWidget.showErrorByString('Требуется обновление программы');
        //TODO: сменить на диалог и запретить работу при наличии обязательного обновления
      } else if (checkResult == 1) {
        NsgErrorWidget.showErrorByString('Есть более новая версия. Рекомендуется обновление программы');
      }
      if (token == '') {
        await _anonymousLogin(onRetry);
      } else {
        try {
          var result = await _checkToken(onRetry);
          if (!result) {
            debugPrint('CheckToken - Сервер отверг токен');
            await _anonymousLogin(onRetry);
          }
        } on NsgApiException catch (e) {
          if (e.error.errorType == null) {
          } else {
            rethrow;
          }
          await _anonymousLogin(onRetry);
        }
      }
    }
    setLocale(localeName: 'en');
    if (allowConnect && isAnonymous && loginRequired && serverUri.isNotEmpty) {
      await openLoginPage().then((value) => controller.loadProviderData());
    } else {
      await controller.loadProviderData();
    }
  }

  Future<Image> getCaptcha() async {
    var response = await imageRequest(
        debug: isDebug, function: 'GetCaptcha', url: '$serverUri/$authorizationApi/GetCaptcha', method: 'GET', headers: getAuthorizationHeader());

    return response;
  }

  Future<NsgLoginResponse> phoneLoginRequestSMS(
      {required String phoneNumber, required String securityCode, NsgLoginType? loginType, required String firebaseToken}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    if (securityCode == '') {
      login.register = true;
    }
    login.securityCode = securityCode == '' ? defaultSecurityCode : securityCode;
    login.firebaseToken = firebaseToken;
    var s = login.toJson();
    Map<String, dynamic>? response;
    //await nsgFutureProgressAndException(func: () async {
    response = await (baseRequest(
        function: 'PhoneLoginRequestSMS',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginRequestSMS',
        method: 'POST',
        params: s));
    //}
    //);

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      smsRequestedTime = DateTime.now();
    }
    return loginResponse;
  }

  ///Регистрация нового пользователя/восстановление пароля по e-mail или вход по паролю
  ///Опраделяется наличием или отсутствием securityCode
  ///В последнем случае, пользователю будет отправлен код верификации для дальнейшего использования в phoneLogin
  Future<NsgLoginResponse> phoneLoginPassword({required String phoneNumber, required String securityCode, NsgLoginType? loginType}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    //Если securityCode пустой, то это регистрация пользователя/восстановление пароля
    //Такая "хитрая" система сделана для совместимости со старыми версиями приложения
    //и со временем может быть заменена на раздельные функции или на новую систему авторизации
    if (securityCode == '') {
      login.register = true;
    }
    //Если securityCode не задан, заполняем его специальной фразой.
    //По всей видимости, для проверки ее на стороне сервера
    //Скорее всего, смысла в этом нет, оставлено для совместимости
    login.securityCode = securityCode == '' ? defaultSecurityCode : securityCode;
    var s = login.toJson();

    var response = await (baseRequest(
        function: 'PhoneLoginRequestSMS',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginRequestSMS',
        method: 'POST',
        params: s));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
      if (!isAnonymous && saveToken) {
        var _prefs = await SharedPreferences.getInstance();
        await _prefs.setString(applicationName, token!);
      }
    }
    return loginResponse;
  }

  ///Вход по телефону или e-mail с проверкой по полученному ранее securityCode
  ///phoneNumber - телефон или e-mail пользователя, на который был оправлен проверочный код
  ///(запрошенному ранее, например, функцией phoneLoginPassword)
  ///Параметр register опредлеляет просто вход по телефону/почте (false) или установку нового пароля пользователя (true)
  Future<NsgLoginResponse> phoneLogin({required String phoneNumber, required String securityCode, bool? register, String? newPassword}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    login.register = register ?? false;
    login.newPassword = newPassword;
    var s = login.toJson();

    try {
      var response = await (baseRequest(
          function: 'PhoneLogin', headers: getAuthorizationHeader(), url: '$serverUri/$authorizationApi/PhoneLogin', method: 'POST', params: s));

      var loginResponse = NsgLoginResponse.fromJson(response);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      if (!isAnonymous && saveToken) {
        var _prefs = await SharedPreferences.getInstance();
        await _prefs.setString(applicationName, token!);
      }

      return loginResponse;
    } catch (e) {
      getx.Get.snackbar('ОШИБКА', 'Произошла ошибка. Попробуйте еще раз.',
          isDismissible: true,
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red[200],
          colorText: Colors.black,
          snackPosition: getx.SnackPosition.bottom);
    }
    return NsgLoginResponse(isError: true, errorCode: 500);
  }

  Future<bool> logout(NsgBaseController controller) async {
    try {
      await baseRequest(function: 'Logout', headers: getAuthorizationHeader(), url: '$serverUri/$authorizationApi/Logout', method: 'GET');
    } catch (ex) {
      debugPrint('ERROR logout: ${ex.toString()}');
    }
    if (!isAnonymous) {
      var _prefs = await SharedPreferences.getInstance();
      await _prefs.remove(applicationName);
      isAnonymous = true;
      token = '';
    }
    await _anonymousLogin(controller.onRetry);
    return true;
  }

  Future resetUserToken() async {
    //if (name == '' || name == null) name = authorizationApi;
    var _prefs = await SharedPreferences.getInstance();
    await _prefs.remove(applicationName);
    isAnonymous = true;
    token = '';
  }

  Future<bool> _anonymousLogin(FutureOr<void> Function(Exception)? onRetry) async {
    var response = await (baseRequest(
        function: 'AnonymousLogin',
        url: '$serverUri/$authorizationApi/AnonymousLogin',
        method: 'GET',
        params: {},
        autoRepeate: true,
        autoRepeateCount: 1000,
        onRetry: onRetry));

    var loginResponse = NsgLoginResponse.fromJson(response);
    token = loginResponse.token;
    isAnonymous = loginResponse.isAnonymous;
    return true;
  }

  Future<bool> _checkToken(FutureOr<void> Function(Exception)? onRetry) async {
    var params = <String, dynamic>{};
    params['firebaseToken'] = firebaseToken;
    var response = await (baseRequest(
        function: 'CheckToken',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/CheckToken',
        method: 'GET',
        params: params,
        autoRepeate: true,
        autoRepeateCount: 1000,
        onRetry: onRetry));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0 || loginResponse.errorCode == 402) {
      if (!isAnonymous) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      return true;
    }
    throw NsgApiException(NsgApiError(code: loginResponse.errorCode));
  }

  Future<int> _checkVersion(FutureOr<void> Function(Exception)? onRetry) async {
    var params = <String, dynamic>{};
    params['appId'] = applicationName;
    params['version'] = applicationVersion;
    try {
      var response = await (baseRequest(
          function: 'CheckVersion',
          headers: getAuthorizationHeader(),
          url: '$serverUri/$authorizationApi/CheckVersion',
          method: 'GET',
          params: params,
          autoRepeate: true,
          autoRepeateCount: 1000,
          onRetry: onRetry));
      var loginResponse = NsgLoginResponse.fromJson(response);
      return loginResponse.errorCode;
    } on NsgApiException catch (e) {
      if (e.error.code == 404) {
        return 0;
      }
    }
    return 0;
  }

  ///Передает локаль на сервер для получения всех строковых значений в локали пользователя
  Future<int> setLocale({required String localeName, FutureOr<void> Function(Exception)? onRetry}) async {
    var params = <String, dynamic>{};
    params['locale'] = localeName;
    try {
      var response = await (baseRequest(
          function: 'SetLocale',
          headers: getAuthorizationHeader(),
          url: '$serverUri/$authorizationApi/SetLocale',
          method: 'GET',
          params: params,
          autoRepeate: true,
          autoRepeateCount: 1000,
          onRetry: onRetry));
      var loginResponse = NsgLoginResponse.fromJson(response);
      return loginResponse.errorCode;
    } on NsgApiException catch (e) {
      if (e.error.code == 404) {
        return 0;
      }
    }
    return 0;
  }

  Map<String, String> getAuthorizationHeader() {
    var map = <String, String>{};
    if (token != '' && token != null) map['Authorization'] = token!;
    return map;
  }

  ///Вызывается при необходимости открыть окно логина
  Future openLoginPage() async {
    if (eventOpenLoginPage != null) {
      await eventOpenLoginPage!();
    } else {
      //TODO: действие открытия окна login по умолчанию
    }
  }
}
