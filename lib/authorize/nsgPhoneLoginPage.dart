// ignore_for_file: file_names

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:get/get.dart';
import 'package:hovering/hovering.dart';
import 'package:nsg_controls/nsg_controls.dart';
import '../nsg_data.dart';

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
  }) {
    NsgPhoneLoginParams.defaultParams = widgetParams;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widgetParams.appbar! ? getAppBar(context) : null,
      //backgroundColor: Colors.white,
      body: Container(
          decoration: BoxDecoration(color: nsgtheme.colorMain.withOpacity(0.1)), child: NsgPhoneLoginWidget(this, provider, widgetParams: widgetParams)),
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
      checkColor: nsgtheme.colorText,
      toggleInside: true,
      simple: true,
      margin: const EdgeInsets.only(top: 5, bottom: 5),
      label: widgetParams.textRememberUser,
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

  Widget getBackground() {
    Widget background = const SizedBox();
    return background;
  }

  Widget? getButtons() {
    return null;
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
  const NsgPhoneLoginWidget(this.loginPage, this.provider, {super.key, this.widgetParams});
}

class _NsgPhoneLoginWidgetState extends State<NsgPhoneLoginWidget> {
  Image? captureImage;
  String phoneNumber = '';
  String email = '';
  String captchaCode = '';
  bool isCaptchaLoading = false;
  int currentStage = _NsgPhoneLoginWidgetState.stagePreLogin;
  bool isLoginSuccessfull = false;
  String password = '';
  PhoneInputFormatter phoneFormatter = PhoneInputFormatter();
  late NsgLoginType loginType;
  //Осталось секунд до автообновления капчи. Если -1, то капча еще не получена
  //и таймер запускать нет смысла
  int secondsLeft = -1;
  //таймер, запускаемый по факту получения капчи. С автообновлением капчи через 2 минуты
  Timer? updateTimer;

  //TODO: заполнять токен!!!
  String firebaseToken = '';

  ///Get captcha and send request for SMS
  ///This is first stage of authorization
  static int stagePreLogin = 1;

  @override
  void initState() {
    super.initState();
    widget.loginPage.callback.sendDataPressed = () => doSmsRequest(loginType: loginType, password: password, firebaseToken: firebaseToken);
    if (widget.widgetParams!.usePhoneLogin) {
      loginType = NsgLoginType.phone;
    } else {
      loginType = NsgLoginType.email;
    }
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
        if (widget.widgetParams != null) {
          NsgNavigator.instance.offAndToPage(widget.widgetParams!.mainPage);
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(color: nsgtheme.colorMainBack, borderRadius: const BorderRadius.all(Radius.circular(3.0))),
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
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  widget.widgetParams!.headerMessage,
                                  style: TextStyle(color: nsgtheme.colorText),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : const SizedBox(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            widget.widgetParams!.headerMessageLogin,
                            style: widget.widgetParams!.headerMessageStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (widget.widgetParams!.useEmailLogin && widget.widgetParams!.usePhoneLogin)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Expanded(
                                    child: NsgCheckBox(
                                  key: GlobalKey(),
                                  radio: true,
                                  label: widget.widgetParams!.textEnterPhone,
                                  onPressed: (bool currentValue) {
                                    setState(() {
                                      loginType = NsgLoginType.phone;
                                    });
                                  },
                                  value: loginType == NsgLoginType.phone,
                                )),
                                Expanded(
                                    child: NsgCheckBox(
                                        key: GlobalKey(),
                                        radio: true,
                                        label: widget.widgetParams!.textEnterEmail,
                                        onPressed: (bool currentValue) {
                                          setState(() {
                                            loginType = NsgLoginType.email;
                                          });
                                        },
                                        value: loginType == NsgLoginType.email)),
                              ],
                            ),
                          ),
                        if (widget.widgetParams!.usePhoneLogin)
                          if (loginType == NsgLoginType.phone)
                            TextFormField(
                              key: GlobalKey(),
                              cursorColor: Theme.of(context).primaryColor,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [phoneFormatter],
                              style: TextStyle(color: nsgtheme.colorText),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                  ),
                                  filled: true,
                                  fillColor: widget.widgetParams!.phoneFieldColor,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                    borderSide: BorderSide(color: nsgtheme.colorText.withOpacity(0.5), width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                    borderSide: BorderSide(color: nsgtheme.colorText, width: 1.0),
                                  ),
                                  errorStyle: const TextStyle(fontSize: 12),
                                  hintText: widget.widgetParams!.textEnterPhone,
                                  hintStyle: TextStyle(color: nsgtheme.colorText.withOpacity(0.3))),
                              initialValue: phoneNumber,
                              onChanged: (value) => phoneNumber = value,
                              validator: (value) => isPhoneValid(value!) ? null : widget.widgetParams!.textEnterCorrectPhone,
                            ),
                        if (widget.widgetParams!.useEmailLogin)
                          if (loginType == NsgLoginType.email)
                            TextFormField(
                              key: GlobalKey(),
                              cursorColor: Theme.of(context).primaryColor,
                              keyboardType: TextInputType.emailAddress,
                              inputFormatters: null,
                              style: TextStyle(color: nsgtheme.colorText),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                ),
                                filled: true,
                                fillColor: widget.widgetParams!.phoneFieldColor,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                  borderSide: BorderSide(color: nsgtheme.colorText, width: 1.0),
                                ),
                                errorStyle: const TextStyle(fontSize: 12),
                                hintText: widget.widgetParams!.textEnterEmail,
                                hintStyle: TextStyle(color: nsgtheme.colorText.withOpacity(0.3)),
                              ),
                              initialValue: email,
                              onChanged: (value) => email = value,
                              validator: (value) => null,
                            ),
                        if (widget.widgetParams!.usePasswordLogin)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextFormField(
                              obscureText: true,
                              cursorColor: Theme.of(context).primaryColor,
                              keyboardType: TextInputType.visiblePassword,
                              inputFormatters: null,
                              style: TextStyle(color: nsgtheme.colorText),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.only(left: 10, top: 10, right: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                                filled: true,
                                fillColor: widget.widgetParams!.phoneFieldColor,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                  borderSide: BorderSide(color: nsgtheme.colorText.withOpacity(0.5), width: 1.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                  borderSide: const BorderSide(color: Colors.black, width: 1.0),
                                ),
                                errorStyle: const TextStyle(fontSize: 12),
                                hintText: widget.widgetParams!.textEnterPassword,
                                hintStyle: TextStyle(color: nsgtheme.colorText.withOpacity(0.3)),
                              ),
                              onChanged: (value) {
                                password = value;
                              },
                            ),
                          ),
                        if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) widget.loginPage.getRememberMeCheckbox() else const SizedBox(height: 10),
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
                                cursorColor: Theme.of(context).primaryColor,
                                controller: _captchaController,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                  ),
                                  filled: true,
                                  fillColor: widget.widgetParams!.phoneFieldColor,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                    borderSide: BorderSide(color: nsgtheme.colorText.withOpacity(0.5), width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(nsgtheme.borderRadius),
                                    borderSide: const BorderSide(color: Colors.black, width: 1.0),
                                  ),
                                  errorStyle: const TextStyle(fontSize: 12),
                                  hintText: widget.widgetParams!.textEnterCaptcha,
                                  hintStyle: TextStyle(color: nsgtheme.colorText.withOpacity(0.3)),
                                ),
                                style: widget.widgetParams!.textPhoneField,
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (value) => captchaCode = value,
                                validator: (value) => captchaCode.length == 6 ? null : widget.widgetParams!.textEnterCaptcha,
                              ),
                            ),
                          ),
                        widget.loginPage.getButtons() ??
                            NsgButton(
                              margin: const EdgeInsets.only(top: 10),
                              onPressed: () {
                                widget.widgetParams!.phoneNumber = phoneNumber;
                                widget.widgetParams!.loginType = loginType;
                                doSmsRequest(loginType: loginType, password: password, firebaseToken: firebaseToken);
                              },
                              text: 'Выслать код'.toUpperCase(),
                            ),
                        if (widget.widgetParams!.usePasswordLogin)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: InkWell(
                              onTap: () {
                                gotoRegistrationPage(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 10),
                                child: HoverWidget(
                                  hoverChild: const Text(
                                    'Регистрация / Забыл пароль',
                                    style: TextStyle(),
                                  ),
                                  onHover: (PointerEnterEvent event) {},
                                  child: const Text(
                                    'Регистрация / Забыл пароль',
                                    style: TextStyle(decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                NsgNavigator.pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Icon(
                  NsgIcons.close,
                  color: nsgtheme.colorPrimary.b100.withOpacity(0.5),
                  size: 18,
                ),
              ),
            )
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

  void checkRequestSMSanswer(BuildContext? context, NsgLoginResponse answerCode) {
    if (updateTimer != null) {
      updateTimer!.cancel();
    }
    if (answerCode.errorCode == 0 && widget.widgetParams!.usePasswordLogin) {
      NsgMetrica.reportLoginSuccess('Phone');
      NsgNavigator.instance.offAndToPage(widget.widgetParams!.mainPage);
      return;
    }
    if (answerCode.errorCode == 0 && !widget.widgetParams!.usePasswordLogin) {
      gotoNextPage(context);
      return;
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
    NsgMetrica.reportLoginFailed('Phone', answerCode.toString());
    widget.widgetParams!.showError(context, errorMessage);

    if (needRefreshCaptcha) {
      refreshCaptcha();
    } else {}
  }

  void doSmsRequest({NsgLoginType loginType = NsgLoginType.phone, String? password, required String firebaseToken}) {
    var context = Get.context;
    if (!_formKey.currentState!.validate()) return;

    NsgMetrica.reportLoginStart('Phone');

/* -------------------------------------------------------------- Если введён пароль -------------------------------------------------------------- */
    if (password != null && password != '') {
      captchaCode = password;
    }

    if (widget.widgetParams!.usePasswordLogin) {
      widget.provider
          .phoneLoginPassword(phoneNumber: loginType == NsgLoginType.phone ? phoneNumber : email, securityCode: captchaCode, loginType: loginType)
          .then((value) => checkRequestSMSanswer(context, value))
          .catchError((e) {
        widget.widgetParams!.showError(context, widget.widgetParams!.textCheckInternet);
      });
    } else {
      widget.provider
          .phoneLoginRequestSMS(
              phoneNumber: loginType == NsgLoginType.phone ? phoneNumber : email, securityCode: captchaCode, loginType: loginType, firebaseToken: firebaseToken)
          .then((value) => checkRequestSMSanswer(context, value))
          .catchError((e) {
        widget.widgetParams!.showError(context, widget.widgetParams!.textCheckInternet);
      });
    }
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

  void gotoRegistrationPage(BuildContext? context) {
    Navigator.push<bool>(context!, MaterialPageRoute(builder: (context) => _getRegistrationWidget()));
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

  Widget _getRegistrationWidget() {
    return widget.provider.getRegistrationWidget!(widget.provider);
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
