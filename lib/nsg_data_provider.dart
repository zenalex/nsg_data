import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/nsgLoginModel.dart';

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

  Duration requestDuration = Duration(seconds: 15);

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

  ///Connect to server
  Future connect() async {
    if (!_initialized) await initialize();
    if (useNsgAuthorization) {
      if (token == '') {
        await _anonymousLogin();
      } else {
        await _checkToken();
      }
    }
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

  Future _anonymousLogin() async {
    var response = await http
        .get('${serverUri}/${authorizationApi}/AnonymousLogin')
        .catchError((e) {
      return;
    });
    if (response.statusCode == 200) {
      var loginResponse = NsgLoginResponse.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
      token = loginResponse.token;
      isAnonymous = loginResponse.isAnonymous;
    }
  }

  Future _checkToken() async {
    var response = await http
        .get('${serverUri}/${authorizationApi}/CheckToken',
            headers: _getAuthorizationHeader())
        .catchError((e) {
      return;
    });
    if (response.statusCode == 200) {
      var loginResponse = NsgLoginResponse.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
      if (loginResponse.errorCode == 0 || loginResponse.errorCode == 402) {
        token = loginResponse.token;
        isAnonymous = loginResponse.isAnonymous;
      } else if (loginResponse.errorCode == 401) {
        await _anonymousLogin();
      }
    }
  }

  Map<String, String> _getAuthorizationHeader() {
    var map = <String, String>{};
    if (token != '') map['Authorization'] = token;
    return map;
  }
}
