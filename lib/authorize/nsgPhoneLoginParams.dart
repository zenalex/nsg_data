import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NsgPhoneLoginParams {
  double cardSize;
  double iconSize;
  double buttonSize;
  String headerMessage;
  String headerMessageVerification;
  String descriptionMessegeVerification;
  TextStyle? headerMessageStyle;
  String textEnterPhone;
  String textSendSms;
  String textResendSms;
  String textEnterCaptcha;
  String textLoginSuccessful;
  String textEnterCorrectPhone;
  String textCheckInternet;
  TextStyle? descriptionStyle;
  TextStyle? textPhoneField;
  Color? cardColor;
  Color textColor;
  Color fillColor;
  Color disableButtonColor;
  Color? sendSmsButtonColor;
  Color? sendSmsBorderColor;
  Color? phoneIconColor;
  Color? phoneFieldColor;
  dynamic parameter;
  String Function(int)? errorMessageByStatusCode;
  void Function(BuildContext? context, dynamic parameter)? loginSuccessful;
  void Function()? loginFailed;

  static NsgPhoneLoginParams defaultParams = NsgPhoneLoginParams();
  bool? appbar;
  bool? headerMessageVisible;

  NsgPhoneLoginParams({
    this.cardSize = 345.0,
    this.iconSize = 28.0,
    this.buttonSize = 42.0,
    this.headerMessage = 'Welcome',
    this.headerMessageVerification = 'Enter security code',
    this.descriptionMessegeVerification =
        'We sent code in SMS\nto phone number\n{{phone}}',
    this.headerMessageStyle,
    this.textEnterPhone = 'Enter your phone',
    this.textResendSms = 'Send SMS again',
    this.descriptionStyle,
    this.textSendSms = 'Send SMS',
    this.textEnterCaptcha = 'Enter captcha text',
    this.textLoginSuccessful = 'Login successful',
    this.textEnterCorrectPhone = 'Enter correct phone',
    this.textCheckInternet =
        'Cannot compleate request. Check internet connection and repeate.',
    this.textPhoneField,
    this.cardColor,
    this.textColor = Colors.black,
    this.fillColor = Colors.black,
    this.disableButtonColor = Colors.blueGrey,
    this.sendSmsButtonColor,
    this.sendSmsBorderColor,
    this.phoneIconColor,
    this.phoneFieldColor,
    this.errorMessageByStatusCode,
    this.appbar,
    this.headerMessageVisible,
  }) {
    headerMessageStyle ??= TextStyle(
      fontFamily: 'Roboto',
      fontSize: 20.0,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    textPhoneField ??= TextStyle(
      fontSize: 18.0,
      fontFamily: 'Roboto',
      color: Color.fromRGBO(2, 54, 92, 1.0),
      fontWeight: FontWeight.normal,
    );
    headerMessageStyle ??= TextStyle(
      fontFamily: 'Roboto',
      fontSize: 18.0,
      color: Colors.black,
    );
    cardColor ??= Colors.white;
    sendSmsButtonColor ??= Color.fromRGBO(0, 101, 175, 1.0);
    sendSmsBorderColor ??= Color.fromRGBO(0, 301, 175, 1.0);
    phoneIconColor ??= Color.fromRGBO(135, 188, 250, 1.0);
    phoneFieldColor ??= Color.fromRGBO(2, 54, 92, 0.1);

    errorMessageByStatusCode ??= errorMessage;
  }

  String interpolate(String string, {Map<String, dynamic> params = const {}}) {
    var keys = params.keys;
    var result = string;
    for (var key in keys) {
      if (string.contains('{{$key}}')) {
        result = result.replaceAll('{{$key}}', params[key].toString());
      }
    }
    return result;
  }

  String errorMessage(int statusCode) {
    String message;
    switch (statusCode) {
      case 40101:
        message = 'You have to get captha first';
        break;
      case 40102:
        message = 'Captcha is obsolet. Try again!';
        break;
      case 40103:
        message = 'Captcha text is wrong. Try again!';
        break;
      case 40104:
        message = 'You have to enter you phone number!';
        break;
      case 40105:
        message = 'You have to enter captcha text!';
        break;
      case 40300:
        message = 'Wrong security code. Try again!';
        break;
      case 40301:
        message = 'You entered wrong code too many times!';
        break;
      case 40302:
        message = 'Security code is obsolete';
        break;
      case 40303:
        message = 'You have to enter captcha first';
        break;
      default:
        message = statusCode == 0 ? '' : 'Error $statusCode is occured';
    }
    return message;
  }

  void showError(BuildContext? context, String message) {
    if (message == '') return;
    Get.snackbar('ОШИБКА', message,
        isDismissible: true,
        duration: Duration(seconds: 5),
        backgroundColor: Colors.red[200],
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM);
  }
}
