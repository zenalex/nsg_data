// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nsg_controls/nsg_controls.dart';
import 'package:nsg_controls/widgets/nsg_snackbar.dart';
import 'package:nsg_data/nsg_data.dart';
import 'package:hovering/hovering.dart';

class NsgPhoneLoginVerificationPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginParams? widgetParams;

  NsgPhoneLoginVerificationPage(this.provider, {super.key, this.widgetParams});

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

  Widget getBackground() {
    Widget background = const SizedBox();
    return background;
  }

  Widget getButtons() {
    return NsgButton(
      backColor: ControlOptions.instance.colorGrey,
      color: ControlOptions.instance.colorText,
      margin: EdgeInsets.zero,
      onPressed: null,
      text: 'Повторить'.toUpperCase(),
    );
  }

  final callback = CallbackFunctionClass();
  void sendData(BuildContext context) {
    callback.sendData(context);
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
  bool isSMSRequested = false;
  bool isBusy = false;
  int secondsRepeateLeft = 120;
  String captchaCode = '';

  @override
  Widget build(BuildContext context) {
    return _getBody(context);
  }

  @override
  void initState() {
    widget.verificationPage.callback.sendDataPressed =
        (context) => doSmsRequest(context: context, loginType: widget.widgetParams!.usePhoneLogin ? NsgLoginType.phone : NsgLoginType.email);
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
        decoration: BoxDecoration(color: nsgtheme.colorMainDarker, borderRadius: const BorderRadius.all(Radius.circular(3.0))),
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
                    widget.widgetParams!.interpolate(
                        widget.widgetParams!.loginType == NsgLoginType.email
                            ? widget.widgetParams!.descriptionMessegeVerificationEmail
                            : widget.widgetParams!.descriptionMessegeVerificationPhone,
                        params: {'phone': widget.provider.phoneNumber}),
                    style: widget.widgetParams!.descriptionStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15.0),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: nsgtheme.colorText),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: widget.widgetParams!.phoneFieldColor,
                      errorStyle: const TextStyle(fontSize: 12),
                      hintText: widget.widgetParams!.textEnterCode,
                      hintStyle: TextStyle(color: nsgtheme.colorText.withOpacity(0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: nsgtheme.colorText.withOpacity(0.5), width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: nsgtheme.colorText, width: 1.0),
                      ),
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
                            style: TextStyle(color: nsgtheme.colorText),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                              border: InputBorder.none,
                              filled: true,
                              fillColor: widget.widgetParams!.phoneFieldColor,
                              errorStyle: const TextStyle(fontSize: 12),
                              hintText: widget.widgetParams!.textEnterNewPassword,
                              hintStyle: TextStyle(color: nsgtheme.colorText.withOpacity(0.3)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: nsgtheme.colorText.withOpacity(0.5), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: nsgtheme.colorText, width: 1.0),
                              ),
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
                              style: TextStyle(color: nsgtheme.colorText),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                                border: InputBorder.none,
                                filled: true,
                                fillColor: widget.widgetParams!.phoneFieldColor,
                                errorStyle: const TextStyle(fontSize: 12),
                                hintText: widget.widgetParams!.textEnterPasswordAgain,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: nsgtheme.colorText.withOpacity(0.5), width: 1.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: nsgtheme.colorText, width: 1.0),
                                ),
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
                        text: 'Войти'.toUpperCase(),
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

  void doSmsRequest({required BuildContext context, NsgLoginType loginType = NsgLoginType.phone, String? password}) {
    var context = Get.context;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isSMSRequested = true;
    });
    NsgMetrica.reportLoginStart('Phone');

/* -------------------------------------------------------------- Если введён пароль -------------------------------------------------------------- */
    if (password != null && password != '') {
      captchaCode = password;
    }

    widget.provider
        .phoneLoginRequestSMS(
            phoneNumber: widget.widgetParams!.usePhoneLogin ? widget.widgetParams!.phoneNumber : widget.widgetParams!.email,
            securityCode: captchaCode,
            loginType: widget.widgetParams!.usePhoneLogin ? NsgLoginType.phone : NsgLoginType.email)
        .then((value) => checkRequestSMSanswer(context, value))
        .catchError((e) {
      widget.widgetParams!.showError(context, widget.widgetParams!.textCheckInternet);
    });
  }

  void checkRequestSMSanswer(BuildContext? context, NsgLoginResponse answerCode) {
    if (updateTimer != null) {
      updateTimer!.cancel();
    }

    if (answerCode.errorCode == 40300) {
      setState(() {});
      nsgSnackbar(text: answerCode.errorMessage);
      return;
    }
    if (answerCode.errorCode == 0) {
      setState(() {
        isSMSRequested = false;
      });
      nsgSnackbar(text: '${answerCode.secondsRemaining} ${answerCode.secondsBeforeRepeat}');
      NsgMetrica.reportLoginSuccess('Phone');
      //gotoNextPage(context);
    }
    var needRefreshCaptcha = false;
    var errorMessage = widget.widgetParams!.errorMessageByStatusCode!(answerCode.errorCode);
    switch (answerCode.errorCode) {
      case 40102:
        needRefreshCaptcha = true;
        break;
      case 40103:
        needRefreshCaptcha = true;
        break;
      default:
        needRefreshCaptcha = false;
    }
    isSMSRequested = false;
    NsgMetrica.reportLoginFailed('Phone', answerCode.toString());
    widget.widgetParams!.showError(context, errorMessage);

    if (needRefreshCaptcha) {
      //refreshCaptcha();
    } else {
      setState(() {
        isSMSRequested = false;
      });
    }
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
      NsgNavigator.instance.offAndToPage(context, widget.widgetParams!.mainPage);
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
