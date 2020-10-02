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
  final bool _initialized = false;
  bool isAnonymous = true;

  Duration requestDuration = Duration(seconds: 15);

  NsgDataProvider(
      {this.name,
      this.serverUri = 'http://192.168.1.20:5073',
      this.authorizationApi = 'Api/Auth',
      this.useNsgAuthorization = true});

  ///Initialization. Load saved token if useNsgAuthorization == true
  void initialize() async {
    if (_initialized) return;
    if (useNsgAuthorization) {
      if (name == '' || name == null) name = authorizationApi;
      var _prefs = await SharedPreferences.getInstance();
      if (_prefs.containsKey(name)) token = _prefs.getString(name);
    }
  }

  ///Connect to server
  void connect() async {
    if (!_initialized) await initialize();
    if (useNsgAuthorization) {
      if (token == '') {
        await _anonymousLogin();
      } else {
        await _checkToken();
      }
    }
  }

  void getToken() async {
    var login = NsgLoginModel();
    // login.login = _GUEST_LOGIN;
    // login.password = '';
    var s = login.toJson();
    var response = await http
        .post(serverUri + '/' + authorizationApi, body: s)
        .catchError((e) {
      return;
    });
    token = NsgLoginResponse.fromJson(
            json.decode(response.body) as Map<String, dynamic>)
        .token;
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
      //var loginResponse = NsgLoginResponse.fromJson(json.decode(response.body));
      //var isError = loginResponse.isError;
      //var errorMessage = loginResponse.errorMessage;
      return 0;
    }
    return 2;
  }

  void _anonymousLogin() async {
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

  void _checkToken() async {}

  Map<String, String> _getAuthorizationHeader() {
    var map = <String, String>{};
    if (token != '') map['Authorization'] = token;
    return map;
  }
}
