import 'dart:async';
import 'dart:io';
import 'package:dio/adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:nsg_controls/widgets/nsg_error_widget.dart';
import 'package:nsg_data/controllers/nsgBaseController.dart';
import 'package:nsg_data/nsgApiException.dart';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'authorize/nsgPhoneLoginPage.dart';
import 'authorize/nsgPhoneLoginParams.dart';
import 'authorize/nsgPhoneLoginRegistrationPage.dart';
import 'authorize/nsgPhoneLoginVerificationPage.dart';
import 'controllers/nsg_cancel_token.dart';
import 'models/nsgLoginModel.dart';
import 'nsgDataApiError.dart';

class NsgDataProvider {
  ///Token saved after authorization
  String? token = '';
  String serverUri = 'http://192.168.1.20:5073';
  String authorizationApi = 'Api/Auth/Login';
  String? name;
  String applicationName;
  String applicationVersion;
  bool useNsgAuthorization = true;
  bool allowConnect;
  bool _initialized = false;
  bool isAnonymous = true;
  bool saveToken = true;
  String? phoneNumber;
  DateTime? smsRequestedTime;
  bool isDebug = kDebugMode;
  bool loginRequired = true;

  ///Firebase token for this device
  String firebaseToken;

  ///milliseconds
  int requestDuration = 120000;
  int connectDuration = 15000;

  NsgPhoneLoginPage Function(NsgDataProvider provider)? getLoginWidget;
  NsgPhoneLoginPage loginPage() {
    if (getLoginWidget == null) {
      return NsgPhoneLoginPage(this, widgetParams: NsgPhoneLoginParams.defaultParams);
    } else {
      return getLoginWidget!(this);
    }
  }

  Function(NsgDataProvider provider)? getVerificationWidget;
  NsgPhoneLoginVerificationPage get verificationPage {
    if (getVerificationWidget == null) {
      return NsgPhoneLoginVerificationPage(this, widgetParams: NsgPhoneLoginParams.defaultParams);
    } else {
      return getVerificationWidget!(this);
    }
  }

  Function(NsgDataProvider provider)? getRegistrationWidget;
  NsgPhoneLoginRegistrationPage get registrationPage {
    if (getRegistrationWidget == null) {
      return NsgPhoneLoginRegistrationPage(this, widgetParams: NsgPhoneLoginParams.defaultParams);
    } else {
      return getRegistrationWidget!(this);
    }
  }

  NsgDataProvider(
      {this.name,
      required this.applicationName,
      this.serverUri = 'http://alex.nsgsoft.ru:5073',
      this.authorizationApi = 'Api/Auth',
      this.useNsgAuthorization = true,
      this.allowConnect = true,
      required this.firebaseToken,
      required this.applicationVersion});

  ///Initialization. Load saved token if useNsgAuthorization == true
  Future initialize() async {
    if (_initialized) return;
    if (useNsgAuthorization) {
      var _prefs = await SharedPreferences.getInstance();
      if (_prefs.containsKey(applicationName)) {
        token = _prefs.getString(applicationName);
      }
      if (kIsWeb) {
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
      connectTimeout: connectDuration,
      receiveTimeout: requestDuration,
    ));

    //Response<List<dynamic>> response;
    late Response<dynamic> response;

    try {
      if (!kIsWeb) {
        (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            return true;
          };
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
    } on DioError catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ??= ''}');
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
      } else if (e.type == DioErrorType.receiveTimeout || e.type == DioErrorType.sendTimeout) {
        throw NsgApiException(NsgApiError(code: 2, message: 'Истекло время ожидания получения или отправки данных', errorType: e.type));
      } else {
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
        (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            return true;
          };
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
    } on DioError catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ??= ''}');
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
        connectTimeout: connectDuration,
        receiveTimeout: requestDuration));

    late Response<Uint8List> response;

    try {
      if (!kIsWeb) {
        (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            return true;
          };
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
    } on DioError catch (e) {
      debugPrint('dio error. function: $function, error: ${e.error ??= ''}');
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
        await Future.delayed(const Duration(seconds: 60));
      } else if (checkResult == 1) {
        NsgErrorWidget.showErrorByString('Есть более новая версия. Рекомендуется обновление программы');
        await Future.delayed(const Duration(seconds: 10));
      }
      if (token == '') {
        await _anonymousLogin(onRetry);
      } else {
        try {
          await _checkToken(onRetry);
        } on NsgApiException catch (e) {
          if (e.error.errorType == null) {
          } else {
            rethrow;
          }
          await _anonymousLogin(onRetry);
        }
      }
    }
    if (allowConnect && isAnonymous && loginRequired && serverUri.isNotEmpty) {
      await getx.Get.to(loginPage)?.then((value) => controller.loadProviderData());
    } else {
      await controller.loadProviderData();
    }
  }

  Future<Image> getCaptcha() async {
    var response = await imageRequest(
        debug: isDebug, function: 'GetCaptcha', url: '$serverUri/$authorizationApi/GetCaptcha', method: 'GET', headers: getAuthorizationHeader());

    return response;
  }

  Future<int> phoneLoginRequestSMS({required String phoneNumber, required String securityCode, NsgLoginType? loginType}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    if (securityCode == '') {
      login.register = true;
    }
    login.securityCode = securityCode == '' ? 'security' : securityCode;
    var s = login.toJson();

    var response = await (baseRequest(
        function: 'PhoneLoginRequestSMS',
        headers: getAuthorizationHeader(),
        url: '$serverUri/$authorizationApi/PhoneLoginRequestSMS',
        method: 'POST',
        params: s));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      smsRequestedTime = DateTime.now();
    }
    return loginResponse.errorCode;
  }

  Future<int> phoneLoginPassword({required String phoneNumber, required String securityCode, NsgLoginType? loginType}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    login.securityCode = securityCode == '' ? 'security' : securityCode;
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
    return loginResponse.errorCode;
  }

  Future<NsgLoginResponse> phoneLogin({required String phoneNumber, required String securityCode, bool? register, String? newPassword}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
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

  Future<bool> logout() async {
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
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
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

  Map<String, String?> getAuthorizationHeader() {
    var map = <String, String?>{};
    if (token != '') map['Authorization'] = token;
    return map;
  }
}
