import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nsg_data/controllers/nsgBaseController.dart';
import 'package:nsg_data/nsgApiException.dart';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/nsgLoginModel.dart';
import 'nsgDataApiError.dart';

class NsgDataProvider {
  ///Token saved after authorization
  String token = '';
  String serverUri = 'http://192.168.1.20:5073';
  String authorizationApi = 'Api/Auth/Login';
  String name;
  bool useNsgAuthorization = true;
  bool _initialized = false;
  bool isAnonymous = true;
  String phoneNumber;
  DateTime smsRequestedTime;
  bool isDebug = true;

  ///milliseconds
  int requestDuration = 15000;

  NsgDataProvider(
      {this.name,
      this.serverUri = 'http://192.168.1.20:5073',
      this.authorizationApi = 'Api/Auth',
      this.useNsgAuthorization = true});

  ///Initialization. Load saved token if useNsgAuthorization == true
  Future initialize() async {
    if (_initialized) return;
    if (useNsgAuthorization) {
      if (name == '' || name == null) name = authorizationApi;
      var _prefs = await SharedPreferences.getInstance();
      if (_prefs.containsKey(name)) token = _prefs.getString(name);
    }
    _initialized = true;
  }

  Future<dynamic> baseRequestList(
      {final String function,
      final Map<String, dynamic> params,
      final dynamic postData,
      final Map<String, String> headers,
      final String url,
      final int timeout = 15000,
      final String method = 'GET',
      FutureOr<void> Function(Exception) onRetry}) async {
    final _dio = Dio(BaseOptions(
      headers: headers,
      method: method,
      responseType: ResponseType.json,
      contentType: 'application/json',
      connectTimeout: timeout,
      receiveTimeout: timeout,
    ));

    //Response<List<dynamic>> response;
    Response<dynamic> response;

    try {
      if (method == 'GET') {
        response = await _dio.get(url, queryParameters: params);
      } else if (method == 'POST') {
        response =
            await _dio.post(url, queryParameters: params, data: postData);
      }
      if (isDebug) {
        print('HTTP STATUS: ${response.statusCode}');
        print(response.data);
      }

      return response.data;
    } on DioError catch (e) {
      print('dio error. function: $function, error: ${e.error ??= ''}');
      throw NsgApiException(NsgApiError(
          code: 1, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      print('network error. function: $function, error: $e');
      return NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<Map<String, dynamic>> baseRequest(
      {final String function,
      final Map<String, dynamic> params,
      final Map<String, String> headers,
      final String url,
      final int timeout = 15000,
      final String method = 'GET',
      bool autoRepeate = false,
      int autoRepeateCount = 1000,
      FutureOr<bool> Function(Exception) retryIf,
      FutureOr<void> Function(Exception) onRetry}) async {
    if (autoRepeate) {
      final r = RetryOptions(maxAttempts: autoRepeateCount);
      return await r.retry(
          () => _baseRequest(
              function: function,
              params: params,
              headers: headers,
              url: url,
              timeout: timeout,
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
          timeout: timeout,
          method: method);
    }
  }

  Future<Map<String, dynamic>> _baseRequest({
    final String function,
    final Map<String, dynamic> params,
    final Map<String, String> headers,
    final String url,
    final int timeout = 15000,
    final String method = 'GET',
  }) async {
    final _dio = Dio(BaseOptions(
      headers: headers,
      method: method,
      responseType: ResponseType.json,
      contentType: 'application/json',
      connectTimeout: timeout,
      receiveTimeout: timeout,
    ));

    Response<Map<String, dynamic>> response;

    try {
      if (method == 'GET') {
        response = await _dio.get(url, queryParameters: params);
      } else if (method == 'POST') {
        response = await _dio.post(url, data: params);
      }
      if (isDebug) {
        print('HTTP STATUS: ${response.statusCode}');
        print(response.data);
      }

      return response.data;
    } on DioError catch (e) {
      print('dio error. function: $function, error: ${e.error ??= ''}');
      throw NsgApiException(NsgApiError(
          code: 1, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      print('network error. function: $function, error: $e');
      throw NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<Image> imageRequest({
    final String function,
    final Map<String, dynamic> params,
    final Map<String, String> headers,
    final String url,
    final int timeout = 15000,
    final bool debug = false,
    final String method = 'GET',
  }) async {
    final _dio = Dio(BaseOptions(
      headers: headers,
      method: method,
      responseType: ResponseType.json,
      contentType: 'application/json',
      connectTimeout: timeout,
      receiveTimeout: timeout,
    ));

    Response<Uint8List> response;

    try {
      if (method == 'GET') {
        response = await _dio.get<Uint8List>(url,
            queryParameters: params,
            options: Options(responseType: ResponseType.bytes));
      } else if (method == 'POST') {
        response = await _dio.post<Uint8List>(url,
            data: params, options: Options(responseType: ResponseType.bytes));
      }
      if (debug) {
        print('HTTP STATUS: ${response.statusCode}');
        //print(response.data);
      }

      return Image.memory(response.data);
    } on DioError catch (e) {
      print('dio error. function: $function, error: ${e.error ??= ''}');
      throw NsgApiException(NsgApiError(
          code: 1, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      print('network error. function: $function, error: $e');
      throw NsgApiException(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<bool> internetConnected() async {
    return await Connectivity().checkConnectivity() != ConnectivityResult.none;
  }

  ///Connect to server
  ///If error will be occured, NsgApiException will be generated
  Future connect(NsgBaseController controller) async {
    if (!_initialized) await initialize();
    var onRetry = controller != null ? controller.onRetry : null;

    if (useNsgAuthorization) {
      if (token == '') {
        await _anonymousLogin(onRetry);
        return;
      } else {
        try {
          await _checkToken(onRetry);
          return;
        } on NsgApiException catch (e) {
          if (e.error.errorType == null) {
            if (e.error.code != 401) {
              rethrow;
            }
          } else {
            rethrow;
          }
          await _anonymousLogin(onRetry);
          return;
        }
      }
    }
    return;
  }

  Future<Image> getCaptcha() async {
    var response = await imageRequest(
        debug: isDebug,
        function: 'GetCaptcha',
        url: '${serverUri}/${authorizationApi}/GetCaptcha',
        method: 'GET',
        headers: getAuthorizationHeader());

    return response;
  }

  Future<bool> phoneLoginRequestSMS(
      String phoneNumber, String securityCode) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    var s = login.toJson();

    var response = await baseRequest(
        function: 'PhoneLoginRequestSMS',
        headers: getAuthorizationHeader(),
        url: '${serverUri}/${authorizationApi}/PhoneLoginRequestSMS',
        method: 'POST',
        params: s);

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      smsRequestedTime = DateTime.now();
      return true;
    } else {
      throw NsgApiException(NsgApiError(
          code: loginResponse.errorCode, message: 'Error sms request'));
    }
  }

  Future<bool> phoneLogin(String phoneNumber, String securityCode) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    var s = login.toJson();

    var response = await baseRequest(
        function: 'PhoneLogin',
        headers: getAuthorizationHeader(),
        url: '${serverUri}/${authorizationApi}/PhoneLogin',
        method: 'POST',
        params: s);

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
    } else {
      throw NsgApiException(NsgApiError(
          code: loginResponse.errorCode, message: 'Error sms request'));
    }
    if (!isAnonymous) {
      if (name == '' || name == null) name = authorizationApi;
      var _prefs = await SharedPreferences.getInstance();
      await _prefs.setString(name, token);
    }
    return true;
  }

  Future<bool> logout() async {
    await baseRequest(
        function: 'Logout',
        headers: getAuthorizationHeader(),
        url: '${serverUri}/${authorizationApi}/Logout',
        method: 'GET');
    if (!isAnonymous) {
      if (name == '' || name == null) name = authorizationApi;
      var _prefs = await SharedPreferences.getInstance();
      await _prefs.remove(name);
      isAnonymous = true;
      token = '';
    }
    return true;
  }

  Future resetUserToken() async {
    if (name == '' || name == null) name = authorizationApi;
    var _prefs = await SharedPreferences.getInstance();
    await _prefs.remove(name);
    isAnonymous = true;
    token = '';
  }

  Future<bool> _anonymousLogin(
      FutureOr<void> Function(Exception) onRetry) async {
    var response = await baseRequest(
        function: 'AnonymousLogin',
        url: '${serverUri}/${authorizationApi}/AnonymousLogin',
        method: 'GET',
        params: {},
        autoRepeate: true,
        autoRepeateCount: 1000,
        onRetry: onRetry);

    var loginResponse = NsgLoginResponse.fromJson(response);
    token = loginResponse.token;
    isAnonymous = loginResponse.isAnonymous;
    return true;
  }

  Future<bool> _checkToken(FutureOr<void> Function(Exception) onRetry) async {
    var response = await baseRequest(
        function: 'CheckToken',
        headers: getAuthorizationHeader(),
        url: '${serverUri}/${authorizationApi}/CheckToken',
        method: 'GET',
        params: {},
        autoRepeate: true,
        autoRepeateCount: 1000,
        onRetry: onRetry);

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0 || loginResponse.errorCode == 402) {
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
      return true;
    }
    throw NsgApiException(NsgApiError(code: loginResponse.errorCode));
  }

  Map<String, String> getAuthorizationHeader() {
    var map = <String, String>{};
    if (token != '') map['Authorization'] = token;
    return map;
  }
}
