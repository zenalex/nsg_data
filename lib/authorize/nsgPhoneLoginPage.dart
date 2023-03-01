// ignore_for_file: file_names

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:get/get.dart';
import 'package:nsg_controls/nsg_button.dart';
import 'package:nsg_controls/formfields/nsg_checkbox.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginParams.dart';

import '../metrica/nsg_metrica.dart';
import '../nsg_data_provider.dart';

enum NsgLoginType { phone, email }

class NsgPhoneLoginPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginParams widgetParams;
  //final NsgLoginType loginType;
  NsgPhoneLoginPage(
    this.provider, {
    super.key,
    required this.widgetParams,
    //this.loginType = NsgLoginType.phone
  });

  @override
  Widget build(BuildContext context) {
    NsgLoginType loginType;
    if (widgetParams.usePhoneLogin) {
      loginType = NsgLoginType.phone;
    } else {
      loginType = NsgLoginType.email;
    }

    return Scaffold(
      appBar: widgetParams.appbar! ? getAppBar(context) : null,
      //backgroundColor: Colors.white,
      body: NsgPhoneLoginWidget(this, provider, widgetParams: widgetParams, loginType: loginType),
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

  Widget getRememberMeCheckbox() {
    bool initialValue = provider.saveToken;
    var checkbox = NsgCheckBox(
      toggleInside: true,
      simple: true,
      margin: const EdgeInsets.only(top: 5, bottom: 5),
      label: 'Запомнить пользователя',
      onPressed: (currentValue) {
        provider.saveToken = currentValue;
      },
      value: initialValue,
    );
    return checkbox;
  }

  /*Widget background() {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(),
      child: Positioned.fill(
        child: getBackground(),
      ),
    );
  }*/

  Image getBackground() {
    var background = Image.asset(
      'lib/assets/titan-back.png',
      repeat: ImageRepeat.repeat,
    );
    return background;
  }

  Widget getButtons() {
    return const NsgButton(
      margin: EdgeInsets.zero,
      onPressed: null,
      text: 'you need to override getButtons',
    );
  }

  final callback = CallbackFunctionClass();
  void sendData() {
    callback.sendData();
  }
}

class CallbackFunctionClass {
  void Function()? sendDataPressed;

  void sendData() {
    if (sendDataPressed != null) {
      sendDataPressed!();
    }
  }
}

class NsgPhoneLoginWidget extends StatefulWidget {
  @override
  _NsgPhoneLoginWidgetState createState() => _NsgPhoneLoginWidgetState();

  final NsgPhoneLoginPage loginPage;
  final NsgPhoneLoginParams? widgetParams;
  final NsgDataProvider provider;
  final NsgLoginType loginType;
  const NsgPhoneLoginWidget(this.loginPage, this.provider, {super.key, this.widgetParams, required this.loginType});
}

class _NsgPhoneLoginWidgetState extends State<NsgPhoneLoginWidget> {
  Image? captureImage;
  String phoneNumber = '';
  String captchaCode = '';
  bool isCaptchaLoading = false;
  int currentStage = _NsgPhoneLoginWidgetState.stagePreLogin;
  bool isLoginSuccessfull = false;
  bool isSMSRequested = false;
  String password = '';
  PhoneInputFormatter phoneFormatter = PhoneInputFormatter();
  //Осталось секунд до автообновления капчи. Если -1, то капча еще не получена
  //и таймер запускать нет смысла
  int secondsLeft = -1;
  //таймер, запускаемый по факту получения капчи. С автообновлением капчи через 2 минуты
  Timer? updateTimer;

  ///Get captcha and send request for SMS
  ///This is first stage of authorization
  static int stagePreLogin = 1;

  @override
  void initState() {
    super.initState();
    widget.loginPage.callback.sendDataPressed = () => doSmsRequest(loginType: widget.loginType, password: password);
    refreshCaptcha();
  }

  @override
  void dispose() {
    if (updateTimer != null) {
      updateTimer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _getBody(context);
  }

  Widget _getBody(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: widget.loginPage.getBackground(),
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
                  child: widget.loginPage.getLogo(),
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
  TextEditingController? _captchaController;
  Widget _getContext(BuildContext context) {
    if (isLoginSuccessfull) {
      Future.delayed(const Duration(milliseconds: 10)).then((e) {
        if (widget.widgetParams != null && widget.widgetParams!.mainPage != null) {
          Get.offAndToNamed(widget.widgetParams!.mainPage!);
        } else {
          //if (widget.widgetParams!.needOpenPage) {
          Get.back();
          //}
        }

        return getContextSuccessful(context);
      });
    }
    _captchaController ??= TextEditingController();
    return Form(
      key: _formKey,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20.0)),
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
                  TextFormField(
                    cursorColor: Colors.black,
                    keyboardType: widget.loginType == NsgLoginType.phone ? TextInputType.phone : TextInputType.emailAddress,
                    inputFormatters: widget.loginType == NsgLoginType.phone ? [phoneFormatter] : null,
                    style: widget.widgetParams!.textPhoneField,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      filled: true,
                      fillColor: widget.widgetParams!.phoneFieldColor,
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 1.0),
                      ),
                      errorStyle: const TextStyle(fontSize: 12),
                      hintText: widget.widgetParams!.textEnterPhone,
                    ),
                    onChanged: (value) => phoneNumber = value,
                    validator: (value) => widget.loginType == NsgLoginType.phone
                        ? isPhoneValid(value!) && value.length >= 16
                            ? null
                            : widget.widgetParams!.textEnterCorrectPhone
                        : null,
                  ),
                  if (widget.widgetParams!.usePasswordLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextFormField(
                        obscureText: true,
                        cursorColor: Colors.black,
                        keyboardType: widget.loginType == NsgLoginType.phone ? TextInputType.phone : TextInputType.emailAddress,
                        inputFormatters: widget.loginType == NsgLoginType.phone ? [phoneFormatter] : null,
                        style: widget.widgetParams!.textPhoneField,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          filled: true,
                          fillColor: widget.widgetParams!.phoneFieldColor,
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black, width: 1.0),
                          ),
                          errorStyle: const TextStyle(fontSize: 12),
                          hintText: widget.widgetParams!.textEnterPassword,
                        ),
                        onChanged: (value) {
                          password = value;
                        },
                      ),
                    ),
                  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) widget.loginPage.getRememberMeCheckbox(),
                  if (widget.widgetParams!.useCaptcha)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          child: getcaptchaImage(),
                        ),
                        SizedBox(
                          height: 50,
                          width: 40,
                          child: Stack(
                            children: [
                              Align(
                                  alignment: Alignment.topCenter,
                                  child: IconButton(
                                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                                    icon: Icon(
                                      Icons.cached,
                                      color: widget.widgetParams!.phoneIconColor,
                                      size: widget.widgetParams!.buttonSize,
                                    ),
                                    onPressed: () {
                                      refreshCaptcha();
                                    },
                                    //padding: EdgeInsets.all(0.0),
                                  )),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                  secondsLeft.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (widget.widgetParams!.useCaptcha)
                    Container(
                      decoration: const BoxDecoration(
                          //color: widget.widgetParams!.phoneFieldColor,
                          //borderRadius: BorderRadius.circular(5.0),
                          ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
                        child: TextFormField(
                          controller: _captchaController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            filled: true,
                            fillColor: widget.widgetParams!.phoneFieldColor,
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black, width: 1.0),
                            ),
                            errorStyle: const TextStyle(fontSize: 12),
                            hintText: widget.widgetParams!.textEnterCaptcha,
                          ),
                          style: widget.widgetParams!.textPhoneField,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) => captchaCode = value,
                          validator: (value) => captchaCode.length == 6 ? null : widget.widgetParams!.textEnterCaptcha,
                        ),
                      ),
                    ),
                  widget.loginPage.getButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? getcaptchaImage() {
    if (captureImage == null || isCaptchaLoading) {
      return Icon(Icons.hourglass_empty, color: widget.widgetParams!.textColor, size: 40.0);
    }
    return captureImage;
  }

  ///Get captcha from server
  Future<Image> _loadCaptureImage() async {
    Image image;
    try {
      image = await widget.provider.getCaptcha();
    } catch (e) {
      image = Image.asset('lib/assets/no_image.jpg');
    }
    return image;
  }

  void checkRequestSMSanswer(BuildContext? context, int answerCode) {
    if (updateTimer != null) {
      updateTimer!.cancel();
    }
    if (answerCode == 0) {
      setState(() {
        isSMSRequested = false;
      });
      NsgMetrica.reportLoginSuccess('Phone');
      gotoNextPage(context);
    }
    var needRefreshCaptcha = false;
    var errorMessage = widget.widgetParams!.errorMessageByStatusCode!(answerCode);
    switch (answerCode) {
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
      refreshCaptcha();
    } else {
      setState(() {
        isSMSRequested = false;
      });
    }
  }

  void doSmsRequest({NsgLoginType loginType = NsgLoginType.phone, String? password}) {
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
        .phoneLoginRequestSMS(phoneNumber: phoneNumber, securityCode: captchaCode, loginType: loginType)
        .then((value) => checkRequestSMSanswer(context, value))
        .catchError((e) {
      widget.widgetParams!.showError(context, widget.widgetParams!.textCheckInternet);
    });
  }

  void refreshCaptcha() {
    isCaptchaLoading = true;
    if (!widget.widgetParams!.useCaptcha) return;
    _loadCaptureImage().then((value) => setState(() {
          captureImage = value;
          _captchaController!.value = TextEditingValue.empty;
          isCaptchaLoading = false;
          if (updateTimer != null) {
            updateTimer!.cancel();
          }
          secondsLeft = 120;
          updateTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) => captchaTimer(t));
        }));
  }

  void captchaTimer(Timer timer) {
    if (secondsLeft > 0) {
      setState(() {
        secondsLeft--;
      });
    } else {
      updateTimer!.cancel();
      updateTimer = null;
      refreshCaptcha();
    }
  }

  void gotoNextPage(BuildContext? context) async {
    var result = await Navigator.push<bool>(context!, MaterialPageRoute(builder: (context) => _getVerificationWidget()));
    //var result = await Get.to(_getVerificationWidget);
    if (result ??= false) {
      setState(() {
        isLoginSuccessfull = true;
      });
      if (widget.widgetParams!.loginSuccessful != null) {
        widget.widgetParams!.loginSuccessful!(context, widget.widgetParams!.parameter);
      }
    } else {
      refreshCaptcha();
    }
  }

  Widget _getVerificationWidget() {
    return widget.provider.getVerificationWidget!(widget.provider);
  }

  Widget getContextSuccessful(BuildContext context) {
    return Center(
      child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 15.0),
          color: widget.widgetParams!.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                  Text(
                    widget.widgetParams!.textLoginSuccessful,
                    style: widget.widgetParams!.headerMessageStyle,
                  )
                ]))
              ]))),
    );
  }
}
