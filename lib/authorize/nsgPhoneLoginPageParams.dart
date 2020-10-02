import 'package:flutter/material.dart';

class NsgPhoneLoginWidgetParams {
  double cardSize;
  double iconSize;
  double buttonSize;
  String headerMessage;
  TextStyle headerMessageStyle;
  String textEnterPhone;
  String textSendSms;
  String textEnterCaptcha;
  TextStyle descriptionStyle;
  TextStyle textPhoneField;
  Color cardColor;
  Color textColor;
  Color fillColor;
  Color sendSmsButtonColor;
  Color sendSmsBorderColor;
  Color phoneIconColor;
  Color phoneFieldColor;

  static NsgPhoneLoginWidgetParams defaultParams = NsgPhoneLoginWidgetParams();

  NsgPhoneLoginWidgetParams(
      {this.cardSize = 345.0,
      this.iconSize = 28.0,
      this.buttonSize = 48.0,
      this.headerMessage = 'Welcome',
      this.headerMessageStyle,
      this.textEnterPhone = 'Enter your phone',
      this.descriptionStyle,
      this.textSendSms = 'Send SMS',
      this.textEnterCaptcha = 'Enter captcha text',
      this.textPhoneField,
      this.cardColor,
      this.textColor = Colors.black,
      this.fillColor = Colors.black,
      this.sendSmsButtonColor,
      this.sendSmsBorderColor,
      this.phoneIconColor,
      this.phoneFieldColor}) {
    headerMessageStyle ??= TextStyle(
      fontFamily: 'Roboto',
      fontSize: 18.0,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    textPhoneField ??= TextStyle(
      fontSize: 18.0,
      fontFamily: 'Roboto',
      color: Color.fromRGBO(2, 54, 92, 1.0),
      fontWeight: FontWeight.normal,
    );
    descriptionStyle ??= headerMessageStyle;
    cardColor ??= Colors.white;
    sendSmsButtonColor ??= Color.fromRGBO(0, 101, 175, 1.0);
    sendSmsBorderColor ??= Color.fromRGBO(0, 301, 175, 1.0);
    phoneIconColor ??= Color.fromRGBO(135, 188, 250, 1.0);
    phoneFieldColor ??= Color.fromRGBO(2, 54, 92, 0.1);
  }
}
