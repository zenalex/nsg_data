import 'dart:typed_data';
import 'dart:ui';

import 'package:connectivity/connectivity.dart';
import 'package:either_option/either_option.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nsg_data/nsgApiException.dart';
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

  Future<Either<NsgApiError, Map<String, dynamic>>> baseRequest({
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

      return Right(response.data);
    } on DioError catch (e) {
      print('dio error. function: $function, error: ${e.error ??= ''}');
      return Left(NsgApiError(
          code: 1, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      print(2);
      print('network error. function: $function, error: $e');
      return Left(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<Either<NsgApiError, Image>> imageRequest({
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

      return Right(Image.memory(response.data));
    } on DioError catch (e) {
      print('dio error. function: $function, error: ${e.error ??= ''}');
      return Left(NsgApiError(
          code: 1, message: 'Internet connection error', errorType: e.type));
    } catch (e) {
      print(2);
      print('network error. function: $function, error: $e');
      return Left(NsgApiError(code: 0, message: '$e'));
    }
  }

  Future<bool> internetConnected() async {
    return await Connectivity().checkConnectivity() != ConnectivityResult.none;
  }

  ///Connect to server
  ///If error will be occured, NsgApiException will be generated
  Future connect() async {
    if (!_initialized) await initialize();
    if (useNsgAuthorization) {
      if (token == '') {
        var result = await _anonymousLogin();
        result.fold((error) => throw NsgApiException(error), (b) {});
        return;
      } else {
        var result = await _checkToken();

        result.fold((error) {
          if (error.errorType == null) {
            if (error.code != 401) {
              throw NsgApiException(error);
            }
          } else {
            throw NsgApiException(error);
          }
        }, (b) {});
        if (result.isLeft) {
          result = await _anonymousLogin();
        }
        result.fold((error) => throw NsgApiException(error), (b) {});
        return;
      }
    }
    return;
  }

  Future<Either<NsgApiError, Image>> getCaptcha() async {
    var response = await imageRequest(
        debug: isDebug,
        function: 'GetCaptcha',
        url: '${serverUri}/${authorizationApi}/GetCaptcha',
        method: 'GET',
        headers: getAuthorizationHeader());

    return response.fold((error) => Left(error), (data) {
      return Right(data);
    });
  }

  Future<Either<NsgApiError, bool>> phoneLoginRequestSMS(
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

    return response.fold((error) => Left(error), (data) {
      var loginResponse = NsgLoginResponse.fromJson(data);
      if (loginResponse.errorCode == 0) {
        smsRequestedTime = DateTime.now();
        return Right(true);
      } else {
        return Left(NsgApiError(
            code: loginResponse.errorCode, message: 'Error sms request'));
      }
    });
  }

  Future<Either<NsgApiError, bool>> phoneLogin(
      String phoneNumber, String securityCode) async {
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

    Left<NsgApiError, bool> left;
    response.fold((e) => left = Left<NsgApiError, bool>(e), (data) {
      var loginResponse = NsgLoginResponse.fromJson(data);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      } else {
        left = Left<NsgApiError, bool>(NsgApiError(
            code: loginResponse.errorCode, message: 'Error sms request'));
      }
    });
    if (response.isRight && !isAnonymous) {
      if (name == '' || name == null) name = authorizationApi;
      var _prefs = await SharedPreferences.getInstance();
      await _prefs.setString(name, token);
    }
    return response.fold((e) => left, (data) => Right(true));
  }

  Future<Either<NsgApiError, bool>> logout() async {
    var response = await baseRequest(
        function: 'Logout',
        headers: getAuthorizationHeader(),
        url: '${serverUri}/${authorizationApi}/Logout',
        method: 'GET');
    if (response.isRight) {
      if (!isAnonymous) {
        if (name == '' || name == null) name = authorizationApi;
        var _prefs = await SharedPreferences.getInstance();
        await _prefs.remove(name);
        isAnonymous = true;
        token = '';
      }
    }
    return response.fold((e) => Left(e), (data) => Right(true));
  }

  Future resetUserToken() async {
    if (name == '' || name == null) name = authorizationApi;
    var _prefs = await SharedPreferences.getInstance();
    await _prefs.remove(name);
    isAnonymous = true;
    token = '';
  }

  Future<Either<NsgApiError, bool>> _anonymousLogin() async {
    var response = await baseRequest(
        function: 'AnonymousLogin',
        url: '${serverUri}/${authorizationApi}/AnonymousLogin',
        method: 'GET',
        params: {});

    return response.fold((error) => Left(error), (data) {
      var loginResponse = NsgLoginResponse.fromJson(data);
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
      return Right(true);
    });
  }

  Future<Either<NsgApiError, bool>> _checkToken() async {
    var response = await baseRequest(
        function: 'CheckToken',
        headers: getAuthorizationHeader(),
        url: '${serverUri}/${authorizationApi}/CheckToken',
        method: 'GET',
        params: {});

    return response.fold((error) => Left(error), (data) {
      var loginResponse = NsgLoginResponse.fromJson(data);
      if (loginResponse.errorCode == 0 || loginResponse.errorCode == 402) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
        return Right(true);
      }
      return Left(NsgApiError(code: loginResponse.errorCode));
    });
  }

  Map<String, String> getAuthorizationHeader() {
    var map = <String, String>{};
    if (token != '') map['Authorization'] = token;
    return map;
  }
}
