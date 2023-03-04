// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nsg_controls/nsg_controls.dart';
import 'package:nsg_controls/widgets/nsg_snackbar.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/nsg_data_provider.dart';
import 'package:hovering/hovering.dart';
import '../models/nsgLoginModel.dart';
import 'nsgPhoneLoginParams.dart';

class NsgPhoneLoginVerificationPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginParams? widgetParams;

  const NsgPhoneLoginVerificationPage(this.provider, {super.key, this.widgetParams});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widgetParams!.appbar! ? getAppBar(context) : null,
      //backgroundColor: Colors.white,
      body: NsgPhoneLoginVerificationWidget(this, provider, widgetParams: widgetParams),
    );
  }

  AppBar getAppBar(BuildContext context) {
    return AppBar(title: const Text(''), centerTitle: true);
  }

  Widget getLogo() {
    var logo = const Image(
      image: AssetImage('lib/assets/logo-wfrs.png', package: 'nsg_data'),
      width: 140.0,
      height: 140.0,
      alignment: Alignment.center,
    );
    return logo;
  }

  Image getBackground() {
    var background = Image.asset(
      'lib/assets/titan-back.png',
      repeat: ImageRepeat.repeat,
    );
    return background;
  }

  Widget getButtons() {
    return const ElevatedButton(
      onPressed: null,
      child: Text('you need to override getButtons'),
    );
  }
}

class NsgPhoneLoginVerificationWidget extends StatefulWidget {
  final NsgPhoneLoginParams? widgetParams;
  final NsgDataProvider provider;
  final NsgPhoneLoginVerificationPage verificationPage;

  const NsgPhoneLoginVerificationWidget(this.verificationPage, this.provider, {super.key, this.widgetParams});
  @override
  State<StatefulWidget> createState() => _NsgPhoneLoginVerificationState();
}

class _NsgPhoneLoginVerificationState extends State<NsgPhoneLoginVerificationWidget> {
  Timer? updateTimer;
  String newPassword = '';
  String newPassword2 = '';
  bool isBusy = false;
  int secondsRepeateLeft = 120;
  @override
  Widget build(BuildContext context) {
    return _getBody(context);
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }

  void startTimer() {
    updateTimer ??= updateTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) => updateTimerEvent(t));
  }

  void stopTimer() {
    if (updateTimer != null) {
      updateTimer!.cancel();
      updateTimer = null;
    }
  }

  Widget _getBody(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: widget.verificationPage.getBackground(),
        ),
        Align(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  child: widget.verificationPage.getLogo(),
                ),
                Container(
                  child: _getContext(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  final _formKey = GlobalKey<FormState>();
  String securityCode = '';
  Widget _getContext(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(3.0)),
          boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.15), offset: Offset(0.0, 4.0), blurRadius: 4.0, spreadRadius: 2.0)],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        padding: const EdgeInsets.all(15.0),
        width: widget.widgetParams!.cardSize,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  widget.widgetParams!.headerMessageVisible == true
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Text(
                            widget.widgetParams!.headerMessage,
                            style: widget.widgetParams!.headerMessageStyle,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox(),
                  SizedBox(height: widget.widgetParams!.headerMessageVisible == true ? 5.0 : 0.0),
                  Text(
                    widget.widgetParams!.headerMessageVerification,
                    style: widget.widgetParams!.headerMessageStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15.0),
                  Text(
                    widget.widgetParams!.interpolate(widget.widgetParams!.descriptionMessegeVerification, params: {'phone': widget.provider.phoneNumber}),
                    style: widget.widgetParams!.descriptionStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15.0),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    style: widget.widgetParams!.textPhoneField,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: true,
                      fillColor: widget.widgetParams!.phoneFieldColor,
                      errorStyle: const TextStyle(fontSize: 12),
                      hintText: widget.widgetParams!.textEnterCode,
                    ),
                    onChanged: (text) {
                      securityCode = text;
                    },
                  ),
                  const SizedBox(height: 15.0),
                  widget.verificationPage.getButtons(),
                  if (widget.widgetParams!.usePasswordLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Column(
                        children: [
                          TextFormField(
                            keyboardType: TextInputType.number,
                            style: widget.widgetParams!.textPhoneField,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              filled: true,
                              fillColor: widget.widgetParams!.phoneFieldColor,
                              errorStyle: const TextStyle(fontSize: 12),
                              hintText: widget.widgetParams!.textEnterNewPassword,
                            ),
                            onChanged: (text) {
                              newPassword = text;
                              //                            checkSecurityCode(context, securityCode);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              style: widget.widgetParams!.textPhoneField,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                filled: true,
                                fillColor: widget.widgetParams!.phoneFieldColor,
                                errorStyle: const TextStyle(fontSize: 12),
                                hintText: widget.widgetParams!.textEnterPasswordAgain,
                              ),
                              onChanged: (text) {
                                newPassword2 = text;
                              },
                            ),
                          ),
                          if (widget.widgetParams!.usePasswordLogin)
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: NsgButton(
                                margin: EdgeInsets.zero,
                                onPressed: () {
                                  if (newPassword != newPassword2) {
                                    nsgSnackbar(text: 'Пароли не совпадают');
                                  } else if (newPassword.isEmpty || newPassword2.isEmpty) {
                                    nsgSnackbar(text: 'Введите новый пароль в оба текстовых поля');
                                  } else {
                                    widget.provider
                                        .phoneLogin(
                                            phoneNumber: widget.provider.phoneNumber!, securityCode: securityCode, register: true, newPassword: newPassword)
                                        .then((result) => checkLoginResult(context, result));
                                  }
                                },
                                text: 'Задать пароль'.toUpperCase(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (!widget.widgetParams!.usePasswordLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: NsgButton(
                        margin: EdgeInsets.zero,
                        onPressed: () {
                          if (newPassword != newPassword2) {
                            nsgSnackbar(text: 'Пароли не совпадают');
                          } else {
                            widget.provider
                                .phoneLogin(phoneNumber: widget.provider.phoneNumber!, securityCode: securityCode, register: true, newPassword: newPassword)
                                .then((result) => checkLoginResult(context, result));
                          }
                        },
                        text: 'Проверить'.toUpperCase(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () {
                        gotoLoginPage(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: HoverWidget(
                          hoverChild: const Text(
                            'Вернуться на страницу входа',
                            style: TextStyle(),
                          ),
                          onHover: (PointerEnterEvent event) {},
                          child: const Text(
                            'Вернуться на страницу входа',
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void gotoLoginPage(BuildContext? context) {
    Navigator.push<bool>(context!, MaterialPageRoute(builder: (context) => _getLoginWidget()));
  }

  Widget _getLoginWidget() {
    return widget.provider.getLoginWidget!(widget.provider);
  }

  void checkLoginResult(BuildContext context, NsgLoginResponse answer) {
    var answerCode = answer.errorCode;
    if (answerCode != 0) {
      var needEnterCaptcha = (answerCode > 40100 && answerCode < 40400);
      var errorMessage = answer.errorMessage;
      if (errorMessage == '') {
        widget.widgetParams!.errorMessageByStatusCode!(answerCode);
      }
      showError(errorMessage, needEnterCaptcha);
    } else {
      NsgNavigator.instance.offAndToPage(widget.widgetParams!.mainPage);
    }
  }

  Future showError(String errorMessage, bool needEnterCaptcha) async {
    widget.widgetParams!.showError(context, errorMessage);
    // if (needEnterCaptcha) {
    //   stopTimer();
    //   setState(() {
    //     isBusy = true;
    //   });
    //   await Future.delayed(const Duration(seconds: 3));
    //   Navigator.pop(context, false);
    // }
  }

  void updateTimerEvent(Timer t) {
    if (widget.provider.smsRequestedTime == null) {
      stopTimer();
    }
    setState(() {
      secondsRepeateLeft = 120 - DateTime.now().difference(widget.provider.smsRequestedTime!).inSeconds;
      secondsRepeateLeft = secondsRepeateLeft < 0 ? 0 : secondsRepeateLeft;
    });
  }
}
