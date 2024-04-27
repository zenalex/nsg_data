/*import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data.dart' as nsg_data;
import 'package:shared_preferences/shared_preferences.dart';

import 'nsg_login_model.dart';
import 'nsg_login_params.dart';
import 'nsg_login_response.dart';

///Тип выбранной пользователем авторизации
enum NsgLoginType { phone, email }

///Стандартный функционал авторизации через телефон и/или e-mail
class NsgLoginProvider {
  String phoneNumber = '';

  ///Основной провайдер данных
  nsg_data.NsgDataProvider provider;

  ///Сохранять ли токен локально на устройстве
  bool saveToken = true;

  ///Время запроса sms для ограничения времени переодичности запросов
  DateTime? smsRequestedTime;

  ///Сохранять ли токен локально на в браузере по умолчанию.
  ///Фактически определяется параметром saveToken
  bool saveTokenWebDefaultTrue = false;

  ///Настройки параметров логина
  final NsgLoginParams widgetParams;

  ///Функция, вызываемая при необходимости отображения окна входа
  final Future Function()? eventOpenLoginPage;

  NsgLoginProvider({required this.provider, required this.widgetParams, this.eventOpenLoginPage});

  Future<NsgLoginResponse> phoneLoginRequestSMS(
      {required String phoneNumber, required String securityCode, NsgLoginType? loginType, required String firebaseToken}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    if (securityCode == '') {
      login.register = true;
    }
    login.securityCode = securityCode == '' ? 'security' : securityCode;
    login.firebaseToken = firebaseToken;
    var s = login.toJson();
    Map<String, dynamic>? response;

    response = await (provider.baseRequest(
        function: 'PhoneLoginRequestSMS',
        headers: provider.getAuthorizationHeader(),
        url: '${provider.serverUri}/${provider.authorizationApi}/PhoneLoginRequestSMS',
        method: 'POST',
        params: s));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      smsRequestedTime = DateTime.now();
    }
    return loginResponse;
  }

  Future<NsgLoginResponse> phoneLoginPassword({required String phoneNumber, required String securityCode, NsgLoginType? loginType}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    if (loginType != null) login.loginType = loginType;
    login.securityCode = securityCode == '' ? 'security' : securityCode;
    var s = login.toJson();

    var response = await (provider.baseRequest(
        function: 'PhoneLoginRequestSMS',
        headers: provider.getAuthorizationHeader(),
        url: '${provider.serverUri}/${provider.authorizationApi}/PhoneLoginRequestSMS',
        method: 'POST',
        params: s));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      provider.token = loginResponse.token;
      provider.isAnonymous = loginResponse.isAnonymous;
      if (!provider.isAnonymous && saveToken) {
        var prefs = await SharedPreferences.getInstance();
        await prefs.setString(provider.applicationName, provider.token!);
      }
    }
    return loginResponse;
  }

  Future<NsgLoginResponse> phoneLogin({required String phoneNumber, required String securityCode, bool? register, String? newPassword}) async {
    this.phoneNumber = phoneNumber;
    var login = NsgLoginModel();
    login.phoneNumber = phoneNumber;
    login.securityCode = securityCode;
    login.register = register ?? false;
    login.newPassword = newPassword;
    var s = login.toJson();

    var response = await (provider.baseRequest(
        function: 'PhoneLogin',
        headers: provider.getAuthorizationHeader(),
        url: '${provider.serverUri}/${provider.authorizationApi}/PhoneLogin',
        method: 'POST',
        params: s));

    var loginResponse = NsgLoginResponse.fromJson(response);
    if (loginResponse.errorCode == 0) {
      provider.token = loginResponse.token;
      provider.isAnonymous = loginResponse.isAnonymous;
    }
    if (!provider.isAnonymous && provider.saveToken) {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString(provider.applicationName, provider.token!);
    }

    return loginResponse;
  }

  Future<Image> getCaptcha() async {
    var response = await provider.imageRequest(
        debug: provider.isDebug,
        function: 'GetCaptcha',
        url: '${provider.serverUri}/${provider.authorizationApi}/GetCaptcha',
        method: 'GET',
        headers: provider.getAuthorizationHeader());

    return response;
  }

  Future openLoginPage() async {
    if (eventOpenLoginPage != null) {
      eventOpenLoginPage!();
    } else {
      //TODO: действие открытия окна login по умолчанию
    }
  }
}
*/