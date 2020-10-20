import 'dart:convert';
import 'dart:ui';

import 'package:connectivity/connectivity.dart';
import 'package:either_option/either_option.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/nsgLoginModel.dart';
import 'nsgDataApiError.dart';

class NsgDataProvider extends GetxController {
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

    Response<Map<String, dynamic>> response;

    try {
      if (method == 'GET') {
        response = await _dio.get(url, queryParameters: params);
      } else if (method == 'POST') {
        response = await _dio.post(url, data: params);
      }

      if (debug) {
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

  Future<bool> internetConnected() async {
    return await Connectivity().checkConnectivity() != ConnectivityResult.none;
  }

  ///Connect to server
  Future<Either<NsgApiError, bool>> connect() async {
    if (!_initialized) await initialize();
    if (useNsgAuthorization) {
      if (token == '') {
        var result = await _anonymousLogin();
        return result;
      } else {
        var result = await _checkToken();
        result.fold((error) async {
          if (error.errorType == null) {
            if (error.code == 401) {
              var result = await _anonymousLogin();
              return result;
            }
            return Left(error);
          }
          return Left(error);
        }, (b) {
          return Right(true);
        });
      }
    }
    return Right(true);
  }

  Future<Image> getCaptcha() async {
    var response = await http
        .get('${serverUri}/${authorizationApi}/GetCaptcha',
            headers: _getAuthorizationHeader())
        .catchError((e) {
      return;
    });
    if (response.statusCode == 200) {
      return Image.memory(response.bodyBytes);
    } else {
      return null;
    }
  }

  Future<int> phoneLoginRequestSMS(
      String phoneNumber, String securityCode) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    var s = login.toJson();

    var response = await http
        .post('${serverUri}/${authorizationApi}/PhoneLoginRequestSMS',
            headers: _getAuthorizationHeader(), body: s)
        .catchError((e) {
      return 1;
    });
    if (response.statusCode == 200) {
      var loginResponse = NsgLoginResponse.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
      if (loginResponse.errorCode == 0) {
        smsRequestedTime = DateTime.now();
      }
      return loginResponse.errorCode ?? 5000;
    }
    return 6000;
  }

  Future<int> phoneLogin(String phoneNumber, String securityCode) async {
    this.phoneNumber = phoneNumber;
    var login = NsgPhoneLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    var s = login.toJson();

    var response = await http
        .post('${serverUri}/${authorizationApi}/PhoneLogin',
            headers: _getAuthorizationHeader(), body: s)
        .catchError((e) {
      return 1;
    });
    if (response.statusCode == 200) {
      var loginResponse = NsgLoginResponse.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
      if (loginResponse.errorCode == 0) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
        if (!isAnonymous) {
          if (name == '' || name == null) name = authorizationApi;
          var _prefs = await SharedPreferences.getInstance();
          await _prefs.setString(name, token);
        }
      }
      return loginResponse.errorCode ?? 5000;
    }
    return 6000;
  }

  Future logout() async {
    await http
        .get('${serverUri}/${authorizationApi}/Logout',
            headers: _getAuthorizationHeader())
        .catchError((e) {});
    if (!isAnonymous) {
      if (name == '' || name == null) name = authorizationApi;
      var _prefs = await SharedPreferences.getInstance();
      await _prefs.remove(name);
      isAnonymous = true;
      token = '';
    }
  }

  Future<Either<NsgApiError, bool>> _anonymousLogin() async {
    var response = await baseRequest(
        debug: isDebug,
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
        debug: isDebug,
        function: 'CheckToken',
        headers: _getAuthorizationHeader(),
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

  Map<String, String> _getAuthorizationHeader() {
    var map = <String, String>{};
    if (token != '') map['Authorization'] = token;
    return map;
  }
}
