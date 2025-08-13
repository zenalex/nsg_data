import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:nsg_data/authorize/nsg_social_login_response.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'authorize/nsg_login_model.dart';
import 'authorize/nsg_login_response.dart';

class NsgDataProvider {
  ///Token saved after authorization
  String? token = '';

  ///server uri (i.e. https://your_server.com:port)
  String serverUri = '';

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

  ///Доступные сперверы
  NsgServerParams availableServers;

  ///milliseconds
  int requestDuration = 120000;
  int connectDuration = 15000;

  static String defaultSecurityCode = 'security';

  String languageCode;

  bool newTableLogic;

  NsgDataProvider({
    this.name,
    required this.applicationName,
    this.serverUri = '', //https://servername.me:1234
    this.authorizationApi = 'Api/Auth',
    this.useNsgAuthorization = true,
    this.allowConnect = true,
    required this.firebaseToken,
    required this.applicationVersion,
    // NsgLoginParamsInterface Function()? widgetLoginParams,
    this.eventOpenLoginPage,
    required this.availableServers,
    this.languageCode = 'ru',
    this.newTableLogic = false,
  }) {
    // widgetParams = widgetLoginParams ?? () => NsgBaseController.defaultLoginParams!;
  }

  ///Initialization. Load saved token if useNsgAuthorization == true
  Future initialize() async {
    if (_initialized) return;
    await loadServerAddress();
    if (useNsgAuthorization) {
      await getCurrentServerToken();
      if (token == null || token!.isEmpty) {
        var _prefs = await SharedPreferences.getInstance();
        if (_prefs.containsKey(applicationName)) {
          token = _prefs.getString(applicationName);
        }
      }
      //Почему-то условие стояло обратное
      isAnonymous = !(token != null && token!.isNotEmpty);
      if (kIsWeb && !saveTokenWebDefaultTrue) {
        // || (!Platform.isAndroid && !Platform.isIOS)) {
        saveToken = false;
      } else {
        saveToken = true;
      }
    }
    _initialized = true;
  }

  static const String _serverName = 'SERVER_URL';

  //формируем имя хранящегося параметра
  String get paramName => '${applicationName}_$_serverName';

  ///Загрузить созраненный адрес сервера на устройстве
  ///Проверяет, если на устройстве есть сохраненный адрес и он находится в списке доступных серверов, устанавливает его текущим
  ///Иначе, не меняет текущий сервер и записывает его в качестве сохраненного
  Future loadServerAddress() async {
    var _prefs = await SharedPreferences.getInstance();

    String? savedServerName;
    if (_prefs.containsKey(paramName)) {
      savedServerName = _prefs.getString(paramName);
    }
    //если нет сохраненного адреса или его нет в списке разрешенных серверов, используем сервер по умолчанию (currentServer)
    if (savedServerName == null ||
        !availableServers.contains(savedServerName)) {
      savedServerName = availableServers.currentServer;
      //Созххраняем новый адрес сервера
      await _prefs.setString(paramName, savedServerName);
    } else {
      //Если есть сохраненный сервер и он в списке разрешенных, устанавливаем его в качестве текущего
      availableServers.currentServer = savedServerName;
    }
    serverUri = availableServers.currentServer;
  }

  ///Установитт новый адрес сервера и сохранить его в начтройках устройства
  Future saveServerAddress(String serverAddress) async {
    var _prefs = await SharedPreferences.getInstance();

    await _prefs.setString(paramName, serverAddress);
  }

  ///Прочитать сохраненный токен для текущего сервера
  Future getCurrentServerToken() async {
    var tokenName =
        '${paramName}_${availableServers.groupNameByAddress(availableServers.currentServer)}';
    var _prefs = await SharedPreferences.getInstance();
    token = '';
    if (_prefs.containsKey(tokenName)) {
      token = _prefs.getString(tokenName);
      isAnonymous = token == null || token!.isEmpty;
    }
  }

  ///Сохранить токен для текущего сервера
  Future saveCurrentServerToken() async {
    var _prefs = await SharedPreferences.getInstance();
    if (token == null || token!.isEmpty) return;
    var tokenName =
        '${paramName}_${availableServers.groupNameByAddress(availableServers.currentServer)}';
    await _prefs.setString(tokenName, token!);
  }

  ///Удалить токен для текущего сервера (например, при logout)
  Future resetCurrentServerToken() async {
    var _prefs = await SharedPreferences.getInstance();
    if (token == null || token!.isEmpty) return;
    var tokenName = '${paramName}_${availableServers.currentServer}';
    await _prefs.remove(tokenName);
  }

  ///Установить адрес сервера по имени (admin/test)
  Future setServerByName(String name) async {
    var newAddress = '';
    availableServers.serverGroups.forEach((key, value) {
      if (value == name) {
        newAddress = key;
      }
    });
    assert(newAddress.isNotEmpty, 'server group $name not found');
    saveServerAddress(newAddress);
  }

  Future<dynamic> baseRequestList({
    final String? function,
    final Map<String, dynamic>? params,
    final dynamic postData,
    final Map<String, String?>? headers,
    final String? url,
    //TODO: сделать настраиваемым параметром
    //final int timeout = timeout,
    final String method = 'GET',
    final NsgCancelToken? cancelToken,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    final _dio = Dio(
      BaseOptions(
        headers: headers,
        method: method,
        responseType: ResponseType.json,
        contentType: 'application/json',
        connectTimeout: Duration(milliseconds: connectDuration),
        receiveTimeout: Duration(milliseconds: requestDuration),
      ),
    );

    //Response<List<dynamic>> response;
    late Response<dynamic> response;

    try {
      if (!kIsWeb) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }

      //Для отладки рассчитаем время выполнения функции
      var counter = NsgDurationCounter();
      if (isDebug) {
        debugPrint('baseRequestList, function=$function');
      }

      //TODO: сделать генерацию метода запроса GET/POST
      var method2 = 'POST';
      var dioCancelToken = cancelToken?.dioCancelToken;
      if (method2 == 'GET') {
        response = await _dio.get(
          url!,
          queryParameters: params,
          cancelToken: dioCancelToken,
        );
      } else if (method2 == 'POST') {
        response = await _dio.post(
          url!,
          queryParameters: params,
          data: postData,
          cancelToken: dioCancelToken,
        );
      }
      if (isDebug) {
        counter.difStart(
          paramName: 'baseRequestList, function=$function. ',
          criticalDuration: 1500,
        );
      }
      return response.data;
    } on DioException catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ?? ''}');
      if (e.response != null) {
        debugPrint('statusCode: ${e.response?.statusCode}');
      }
      if (e.response?.statusCode == 400) {
        //400 - Сервер отказался предоставлять данные. Повторять запрос бессмыслено
        throw NsgApiException(
          NsgApiError(code: 400, message: e.response?.data, errorType: e.type),
        );
      }
      if (e.response?.statusCode == 401) {
        throw NsgApiException(
          NsgApiError(
            code: 401,
            message: 'Authorization error',
            errorType: e.type,
          ),
        );
      }
      if (e.response?.statusCode == 500) {
        var msg = 'ERROR 500';
        if (e.response!.data is Map &&
            (e.response!.data as Map).containsKey('message')) {
          var msgParts = e.response!.data['message'].split('---> ');
          //TODO: в нулевом параметре функция, вызвавшая ишибку - надо где-то показывать
          msg = msgParts.last;
        }
        throw NsgApiException(
          NsgApiError(code: 500, message: msg, errorType: e.type),
        );
      } else if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw NsgApiException(
          NsgApiError(
            code: 2,
            message: 'Timeout while receiving or sending data',
            errorType: e.type,
          ),
        );
      } else {
        debugPrint('###');
        debugPrint('### Error: ${e.error}, type: ${e.type}');
        debugPrint('###');
        throw NsgApiException(
          NsgApiError(
            code: 1,
            message: e.error?.toString() ?? 'Internet connection error',
            errorType: e.type,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'network error. function: $function, error: $function + '
        ' + $e',
      );
      return NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<Map<String, dynamic>?> baseRequest({
    final String? function,
    final Map<String, dynamic>? params,
    final Map<String, String?>? headers,
    final String? url,
    final Duration? timeout,
    //final int timeout = 15000,
    final String method = 'GET',
    bool autoRepeate = false,
    int autoRepeateCount = 1000,
    int maxRepeateDelay = 5,
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    if (autoRepeate) {
      final r = RetryOptions(
        maxAttempts: autoRepeateCount,
        maxDelay: Duration(seconds: maxRepeateDelay),
      );
      return await r.retry(
        () => _baseRequest(
          function: function,
          params: params,
          headers: headers,
          url: url,
          timeout: timeout,
          method: method,
        ),
        retryIf: retryIf,
        onRetry: onRetry,
      );
      // onRetry: (error) => _updateStatusError(error.toString()));
    } else {
      return await _baseRequest(
        function: function,
        params: params,
        headers: headers,
        url: url,
        timeout: timeout,
        method: method,
      );
    }
  }

  Future<Map<String, dynamic>?> _baseRequest({
    final String? function,
    final Map<String, dynamic>? params,
    final Map<String, String?>? headers,
    final String? url,
    final Duration? timeout,
    final String method = 'GET',
  }) async {
    final _dio = Dio(
      BaseOptions(
        headers: headers,
        method: method,
        responseType: ResponseType.json,
        contentType: 'application/json',
        connectTimeout: timeout,
        // connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    late Response<Map<String, dynamic>> response;

    try {
      //BrowserHttpClientAdapter
      if (!kIsWeb) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
      print('BSASE REQUEST: $url, url: $url!, params: $params');
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
      throw NsgApiException(
        NsgApiError(
          code: e.response?.statusCode,
          message: e.error?.toString() ?? 'Internet connection error',
          errorType: e.type,
        ),
      );
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
    final _dio = Dio(
      BaseOptions(
        headers: headers,
        method: method,
        responseType: ResponseType.json,
        contentType: 'application/json',
        connectTimeout: Duration(milliseconds: connectDuration),
        receiveTimeout: Duration(milliseconds: requestDuration),
      ),
    );

    late Response<Uint8List> response;

    try {
      if (!kIsWeb) {
        (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
      if (method == 'GET') {
        response = await _dio.get<Uint8List>(
          url!,
          queryParameters: params,
          options: Options(responseType: ResponseType.bytes),
        );
      } else if (method == 'POST') {
        response = await _dio.post<Uint8List>(
          url!,
          data: params,
          options: Options(responseType: ResponseType.bytes),
        );
      }
      if (debug) {
        debugPrint('HTTP STATUS: ${response.statusCode}');
        //print(response.data);
      }

      return Image.memory(response.data!);
    } on DioException catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ?? ''}');
      throw NsgApiException(
        NsgApiError(
          code: 1,
          message: e.error?.toString() ?? 'Internet connection error',
          errorType: e.type,
        ),
      );
    } catch (e) {
      debugPrint('network error. function: $function, error: $e');
      throw NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<bool> internetConnected() async {
    return true;
    //return await Connectivity().checkConnectivity() != ConnectivityResult.none;
  }

  ///Запросить список актуальных серверов приложения с управляющего сервера
  ///Если список удалось получить - он со=храняется в availableServers, а рекомендованный проставится текущим
  ///Если управляющих серверов указано несколько, запрашиваем сразу по всем для ускорения получения ответа и решения проблемы с неработающими серверами
  Future selectApplicationServer() async {
    if (availableServers.controlServers.isEmpty) {
      return;
    }
  }

  // ///Запрос адреса сервера приложения
  // ///Формат запроса 185.65.105.51/AppConnection?appName=App2&clientVersion=1.0&country=US&serverType=release
  // Future<String> _requestAppServer(String controlServerAddress, String serverType) async {
  //   String url = Uri.parse(controlServerAddress).resolve("AppConnection").toString();

  //   var params = <String, dynamic>{};
  //   params['appName'] = applicationName;
  //   params['clientVersion'] = applicationVersion;
  //   params['country'] = 'me';
  //   params['serverType'] = serverType;
  //   try {
  //     var response = await (baseRequest(
  //       function: 'AppConnection',
  //       headers: getAuthorizationHeader(),
  //       url: url,
  //       method: 'GET',
  //       params: params,
  //       autoRepeate: true,
  //       autoRepeateCount: 1000,
  //       onRetry: null,
  //     ));
  //     return response.toString();
  //   } on NsgApiException catch (e) {
  //     if (e.error.code == 404) {
  //       return '';
  //     }
  //   }
  //   return '';
  // }

  ///Connect to server
  ///If error will be occured, NsgApiException will be generated
  Future connect(NsgBaseController controller) async {
    if (!_initialized) await initialize();
    var onRetry = controller.onRetry;

    if (useNsgAuthorization && allowConnect && serverUri.isNotEmpty) {
      var checkResult = await _checkVersion(onRetry);
      if (checkResult == 2) {
        NsgBaseController.showErrorByString('Application update required');
        //TODO: сменить на диалог и запретить работу при наличии обязательного обновления
      } else if (checkResult == 1) {
        NsgBaseController.showErrorByString(
          'A newer version is available. It is recommended to update the application',
        );
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
      await setLocale(languageCode: languageCode);
    }

    if (allowConnect && isAnonymous && loginRequired && serverUri.isNotEmpty) {
      await openLoginPage().then((value) => controller.loadProviderData());
    } else {
      await controller.loadProviderData();
    }
  }

  Future<Image> getCaptcha() async {
    var response = await imageRequest(
      debug: isDebug,
      function: 'GetCaptcha',
      url: '$serverUri/$authorizationApi/GetCaptcha',
      method: 'GET',
      headers: getAuthorizationHeader(),
    );

    return response;
  }

  Future<NsgLoginResponse> phoneLoginRequestSMS({
    required String phoneNumber,
    required String securityCode,
    NsgLoginType? loginType,
    required String firebaseToken,
  }) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    if (securityCode == '') {
      login.register = true;
    }
    login.securityCode = securityCode == ''
        ? defaultSecurityCode
        : securityCode;
    login.firebaseToken = firebaseToken;
    var s = login.toJson();
    Map<String, dynamic>? response;
    //await nsgFutureProgressAndException(func: () async {
    response = await (baseRequest(
      function: 'PhoneLoginRequestSMS',
      headers: getAuthorizationHeader(),
      url: '$serverUri/$authorizationApi/PhoneLoginRequestSMS',
      method: 'POST',
      params: s,
    ));
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
  Future<NsgLoginResponse> phoneLoginPassword({
    required String phoneNumber,
    required String securityCode,
    NsgLoginType? loginType,
  }) async {
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
    login.securityCode = securityCode == ''
        ? defaultSecurityCode
        : securityCode;
    var s = login.toJson();

    var response = await (baseRequest(
      function: 'PhoneLoginRequestSMS',
      headers: getAuthorizationHeader(),
      url: '$serverUri/$authorizationApi/PhoneLoginRequestSMS',
      method: 'POST',
      params: s,
    ));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
      if (!isAnonymous && saveToken) {
        // var _prefs = await SharedPreferences.getInstance();
        // await _prefs.setString(applicationName, token!);
        await saveCurrentServerToken();
      }
    }
    return loginResponse;
  }

  ///Вход по телефону или e-mail с проверкой по полученному ранее securityCode
  ///phoneNumber - телефон или e-mail пользователя, на который был оправлен проверочный код
  ///(запрошенному ранее, например, функцией phoneLoginPassword)
  ///Параметр register опредлеляет просто вход по телефону/почте (false) или установку нового пароля пользователя (true)
  Future<NsgLoginResponse> phoneLogin({
    required String phoneNumber,
    required String securityCode,
    bool? register,
    String? newPassword,
  }) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    login.register = register ?? false;
    login.newPassword = newPassword;
    var s = login.toJson();

    try {
      var response = await (baseRequest(
        function: 'PhoneLogin',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLogin',
        method: 'POST',
        params: s,
      ));

      var loginResponse = NsgLoginResponse.fromJson(response);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      if (!isAnonymous && saveToken) {
        saveCurrentServerToken();
        // var _prefs = await SharedPreferences.getInstance();
        // await _prefs.setString(applicationName, token!);
      }

      return loginResponse;
    } catch (e) {
      getx.Get.snackbar(
        'ERROR',
        'An error occurred. Please try again.',
        isDismissible: true,
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red[200],
        colorText: Colors.black,
        snackPosition: getx.SnackPosition.bottom,
      );
    }
    return NsgLoginResponse(isError: true, errorCode: 500);
  }

  Future<NsgLoginResponse> requestVK() async {
    var login = NsgLoginModel();

    try {
      var response = await (baseRequest(
        function: 'RequestVK',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginRequestVK',
        method: 'POST',
        params: login.toJson(),
      ));

      var loginResponse = NsgLoginResponse.fromJson(response);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      // if (!isAnonymous && saveToken) {
      if (!isAnonymous) {
        saveCurrentServerToken();
      }

      return loginResponse;
    } catch (e) {
      getx.Get.snackbar(
        'ERROR',
        'An error occurred. Please try again.',
        isDismissible: true,
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red[200],
        colorText: Colors.black,
        snackPosition: getx.SnackPosition.bottom,
      );
    }
    return NsgLoginResponse(isError: true, errorCode: 500);
  }

  Future<NsgLoginResponse> verifyVK(NsgSocialLoginResponse response) async {
    var login = NsgLoginModel();
    login.code = response.code;
    login.deviceId = response.deviceId;
    login.state = response.state;

    try {
      var response = await (baseRequest(
        function: 'VerifyVK',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginVerifyVK',
        method: 'POST',
        params: login.toJson(),
      ));

      var loginResponse = NsgLoginResponse.fromJson(response);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      if (!isAnonymous) {
        saveCurrentServerToken();
      }

      return loginResponse;
    } catch (e) {
      getx.Get.snackbar(
        'ERROR',
        'An error occurred. Please try again.',
        isDismissible: true,
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red[200],
        colorText: Colors.black,
        snackPosition: getx.SnackPosition.bottom,
      );
    }
    return NsgLoginResponse(isError: true, errorCode: 500);
  }

  Future<NsgLoginResponse> requestGoogle() async {
    var login = NsgLoginModel();

    try {
      var response = await (baseRequest(
        function: 'RequestGoogle',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginRequestGoogle',
        method: 'POST',
        params: login.toJson(),
      ));

      var loginResponse = NsgLoginResponse.fromJson(response);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      // if (!isAnonymous && saveToken) {
      if (!isAnonymous) {
        saveCurrentServerToken();
      }

      return loginResponse;
    } catch (e) {
      getx.Get.snackbar(
        'ERROR',
        'An error occurred. Please try again.',
        isDismissible: true,
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red[200],
        colorText: Colors.black,
        snackPosition: getx.SnackPosition.bottom,
      );
    }
    return NsgLoginResponse(isError: true, errorCode: 500);
  }

  Future<NsgLoginResponse> verifyGoogle(NsgSocialLoginResponse response) async {
    var login = NsgLoginModel();
    login.code = response.code;
    login.deviceId = response.deviceId;
    login.state = response.state;

    try {
      var response = await (baseRequest(
        function: 'VerifyGoogle',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginVerifyGoogle',
        method: 'POST',
        params: login.toJson(),
      ));

      var loginResponse = NsgLoginResponse.fromJson(response);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      }
      if (!isAnonymous) {
        saveCurrentServerToken();
      }

      return loginResponse;
    } catch (e) {
      getx.Get.snackbar(
        'ERROR',
        'An error occurred. Please try again.',
        isDismissible: true,
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red[200],
        colorText: Colors.black,
        snackPosition: getx.SnackPosition.bottom,
      );
    }
    return NsgLoginResponse(isError: true, errorCode: 500);
  }

  Future<bool> logout(NsgBaseController controller) async {
    try {
      await baseRequest(
        function: 'Logout',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/Logout',
        method: 'GET',
      );
    } catch (ex) {
      debugPrint('ERROR logout: ${ex.toString()}');
    }
    if (!isAnonymous) {
      resetCurrentServerToken();
      // var _prefs = await SharedPreferences.getInstance();
      // await _prefs.remove(applicationName);
      isAnonymous = true;
      token = '';
    }
    await _anonymousLogin(controller.onRetry);
    return true;
  }

  Future resetUserToken() async {
    resetCurrentServerToken();
    // var _prefs = await SharedPreferences.getInstance();
    // await _prefs.remove(applicationName);
    isAnonymous = true;
    token = '';
  }

  Future<bool> _anonymousLogin(
    FutureOr<void> Function(Exception)? onRetry,
  ) async {
    var response = await (baseRequest(
      function: 'AnonymousLogin',
      url: '$serverUri/$authorizationApi/AnonymousLogin',
      method: 'GET',
      params: {},
      autoRepeate: true,
      autoRepeateCount: 1000,
      onRetry: onRetry,
    ));

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
      onRetry: onRetry,
    ));

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

  Future<Map<String, String>> _getDeviceParams() async {
    final params = <String, String>{};
    final deviceInfo = DeviceInfoPlugin();

    if (!kIsWeb && Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      params['model'] = info.model;
      params['manufacturer'] = info.manufacturer;
      params['versionOS'] = info.version.release;
      params['platform'] = 'Android';
    } else if (!kIsWeb && Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      params['model'] = info.utsname.machine;
      params['manufacturer'] = 'Apple';
      params['versionOS'] = info.systemVersion;
      params['platform'] = 'iOS';
    } else if (!kIsWeb) {
      params['model'] = '';
      params['manufacturer'] = '';
      params['versionOS'] = '';
      params['platform'] = Platform.operatingSystem;
    } else {
      params['model'] = '';
      params['manufacturer'] = '';
      params['versionOS'] = '';
      params['platform'] = 'WEB';
    }

    return params;
  }

  Future<int> _checkVersion(FutureOr<void> Function(Exception)? onRetry) async {
    var params = await _getDeviceParams();
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
        onRetry: onRetry,
      ));
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
  Future<int> setLocale({
    required String languageCode,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    var params = <String, dynamic>{};
    params['locale'] = languageCode;
    try {
      var response = await (baseRequest(
        function: 'SetLocale',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/SetLocale',
        method: 'GET',
        params: params,
        //FIXME: добавить реакцию на 404
        autoRepeate: false,
        autoRepeateCount: 1000,
        onRetry: onRetry,
      ));
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
