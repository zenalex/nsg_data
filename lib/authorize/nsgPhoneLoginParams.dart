// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nsg_controls/widgets/nsg_snackbar.dart';

class NsgPhoneLoginParams {
  bool usePasswordLogin;
  bool usePhoneLogin;
  bool useEmailLogin;
  double cardSize;
  double iconSize;
  double buttonSize;
  String headerMessage;
  String headerMessageVerification;
  String headerMessageLogin;
  String headerMessageRegistration;
  String descriptionMessegeVerification;
  TextStyle? headerMessageStyle;
  String textEnterPhone;
  String textEnterEmail;
  String textSendSms;
  String textResendSms;
  String textEnterCaptcha;
  String textLoginSuccessful;
  String textEnterCorrectPhone;
  String textCheckInternet;
  String textEnterCode;
  String textEnterPassword;
  String textEnterNewPassword;
  String textEnterPasswordAgain;
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
  final bool useCaptcha;
  dynamic parameter;
  String Function(int)? errorMessageByStatusCode;
  void Function(BuildContext? context, dynamic parameter)? loginSuccessful;
  void Function()? loginFailed;
  String mainPage;

  static NsgPhoneLoginParams defaultParams = NsgPhoneLoginParams();
  bool? appbar;
  bool? headerMessageVisible;

  NsgPhoneLoginParams(
      {this.usePasswordLogin = false,
      this.usePhoneLogin = true,
      this.useEmailLogin = false,
      this.cardSize = 345.0,
      this.iconSize = 28.0,
      this.buttonSize = 42.0,
      this.headerMessage = 'NSG Application',
      this.headerMessageLogin = 'Enter',
      this.headerMessageRegistration = 'Registration',
      this.headerMessageVerification = 'Enter security code',
      this.descriptionMessegeVerification = 'We sent code in SMS\nto phone number\n{{phone}}',
      this.headerMessageStyle,
      this.textEnterCode = 'Code',
      this.textEnterPhone = 'Enter your phone',
      this.textEnterEmail = 'Enter your email',
      this.textEnterPassword = 'Enter you password',
      this.textEnterNewPassword = 'Enter new password',
      this.textEnterPasswordAgain = 'Enter password again',
      this.textResendSms = 'Send SMS again',
      this.descriptionStyle,
      this.textSendSms = 'Send SMS',
      this.textEnterCaptcha = 'Enter captcha text',
      this.textLoginSuccessful = 'Login successful',
      this.textEnterCorrectPhone = 'Enter correct phone',
      this.textCheckInternet = 'Cannot compleate request. Check internet connection and repeate.',
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
      this.useCaptcha = true,
      this.mainPage = ''}) {
    headerMessageStyle ??= const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 20.0,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    textPhoneField ??= const TextStyle(
      fontSize: 18.0,
      fontFamily: 'Roboto',
      color: Color.fromRGBO(2, 54, 92, 1.0),
      fontWeight: FontWeight.normal,
    );
    headerMessageStyle ??= const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 18.0,
      color: Colors.black,
    );
    cardColor ??= Colors.white;
    sendSmsButtonColor ??= const Color.fromRGBO(0, 101, 175, 1.0);
    sendSmsBorderColor ??= const Color.fromRGBO(0, 301, 175, 1.0);
    phoneIconColor ??= const Color.fromRGBO(50, 50, 50, 1.0);
    phoneFieldColor ??= const Color.fromRGBO(2, 54, 92, 0.1);

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
    nsgSnackbar(
      type: NsgSnarkBarType.error,
      text: message,
      duration: const Duration(seconds: 5),
    );
  }
}
