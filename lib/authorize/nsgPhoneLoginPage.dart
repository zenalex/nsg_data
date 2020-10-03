import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginPageParams.dart';

import '../nsg_data_provider.dart';

class NsgPhoneLoginPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginWidgetParams widgetParams;
  NsgPhoneLoginPage(this.provider, {this.widgetParams}) : super();

  @override
  Widget build(BuildContext context) {
    if (Scaffold.of(context, nullOk: true) == null) {
      return Scaffold(
        backgroundColor: Colors.blue,
        body: NsgPhoneLoginWidget(provider, widgetParams: widgetParams),
      );
    }
    return NsgPhoneLoginWidget(provider, widgetParams: widgetParams);
  }
}

class NsgPhoneLoginWidget extends StatefulWidget {
  @override
  _NsgPhoneLoginWidgetState createState() => _NsgPhoneLoginWidgetState();

  final NsgPhoneLoginWidgetParams widgetParams;
  final NsgDataProvider provider;

  NsgPhoneLoginWidget(this.provider, {this.widgetParams}) : super();
}

class _NsgPhoneLoginWidgetState extends State<NsgPhoneLoginWidget> {
  Image captureImage;
  String phoneNumber = '';
  String captchaCode = '';
  bool isCaptchaLoading = false;
  int currentStage = _NsgPhoneLoginWidgetState.stagePreLogin;
  bool isSMSRequested = false;
  BuildContext contextForSnackBar;
  PhoneInputFormatter phoneFormatter = PhoneInputFormatter();
  //Осталось секунд до автообновления капчи. Если -1, то капча еще не получена
  //и таймер запускать нет смысла
  int secondsLeft = -1;
  //таймер, запускаемый по факту получения капчи. С автообновлением капчи через 2 минуты
  Timer updateTimer;

  ///Get captcha and send request for SMS
  ///This is first stage of authorization
  static int stagePreLogin = 1;

  ///After SMS is recieved, send verification code to the server.
  ///This is the last stage of authorization
  static int stageVerification = 2;

  @override
  void initState() {
    super.initState();
    refreshCaptcha();
  }

  @override
  void dispose() {
    if (updateTimer != null) {
      updateTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _getBody(context);
  }

  Widget getLogo() {
    var logo = Image(
      image: AssetImage('lib/assets/logo-wfrs.png', package: 'nsg_data'),
      width: 140.0,
      height: 140.0,
      alignment: Alignment.center,
    );
    return logo;
  }

  Widget _getBody(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: getLogo(),
                  ),
                ),
              ],
            ),
            _getContext(context),
          ],
        ),
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();
  Widget _getContext(BuildContext context) {
    return Form(
      key: _formKey,
      child: SizedBox(
        width: widget.widgetParams.cardSize,
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 15.0),
          color: widget.widgetParams.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: Text(
                          widget.widgetParams.headerMessage,
                          style: widget.widgetParams.headerMessageStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Padding(
                      //   padding: EdgeInsets.symmetric(vertical: 10.0),
                      //   child: Text(
                      //     widget.widgetParams.description,
                      //     style: widget.widgetParams.descriptionStyle,
                      //     textAlign: TextAlign.center,
                      //   ),
                      // ),
                      SizedBox(height: 5.0),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.widgetParams.phoneFieldColor,
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(right: 15.0),
                            child: TextFormField(
                              keyboardType: TextInputType.phone,
                              inputFormatters: [phoneFormatter],
                              style: widget.widgetParams.textPhoneField,
                              textAlign: TextAlign.left,
                              decoration: InputDecoration(
                                hintText: widget.widgetParams.textEnterPhone,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5.0, vertical: 13.0),
                                prefixIcon: Icon(
                                  Icons.smartphone,
                                  size: widget.widgetParams.iconSize,
                                  color: widget.widgetParams.phoneIconColor,
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (value) => phoneNumber = value,
                              validator: (value) =>
                                  isPhoneValid(value) && value.length >= 16
                                      ? null
                                      : 'Enter correct phone',
                            ),
                          ),
                        ),
                      ),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 5.0),
                          child: Row(children: [
                            Expanded(child: getcaptchaImage()),
                            Column(children: [
                              TextButton(
                                  child: Icon(
                                    Icons.refresh,
                                    color: widget.widgetParams.phoneIconColor,
                                    size: widget.widgetParams.buttonSize,
                                  ),
                                  onPressed: () {
                                    refreshCaptcha();
                                  }),
                              Text(secondsLeft.toString())
                            ]),
                          ])),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 5.0),
                          child: Container(
                              decoration: BoxDecoration(
                                color: widget.widgetParams.phoneFieldColor,
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 5.0),
                                child: Container(
                                  height: widget.widgetParams.buttonSize,
                                  width: double.infinity,
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                        fillColor:
                                            widget.widgetParams.fillColor,
                                        hintText: widget
                                            .widgetParams.textEnterCaptcha,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 5.0, vertical: 10.0),
                                        border: InputBorder.none),
                                    style: widget.widgetParams.textPhoneField,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    onChanged: (value) => captchaCode = value,
                                    validator: (value) =>
                                        captchaCode.length == 6
                                            ? null
                                            : 'Enter captcha code',
                                  ),
                                ),
                              ))),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: Container(
                          height: widget.widgetParams.buttonSize,
                          width: double.infinity,
                          child: RaisedButton(
                            elevation: 0.0,
                            color: widget.widgetParams.sendSmsButtonColor,
                            disabledColor: widget.widgetParams.fillColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              side: BorderSide(
                                color: widget.widgetParams.sendSmsBorderColor,
                              ),
                            ),
                            onPressed: isSMSRequested
                                ? null
                                : () => doSmsRequest(context),
                            child: Text(
                              widget.widgetParams.textSendSms,
                              style: widget.widgetParams.headerMessageStyle,
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
        ),
      ),
    );
  }

  Widget getcaptchaImage() {
    if (captureImage == null || isCaptchaLoading) {
      return Icon(Icons.hourglass_empty, color: widget.widgetParams.textColor);
    }
    return captureImage;
  }

  ///Get captcha from server
  Future<Image> _loadCaptureImage() async {
    return await widget.provider.getCaptcha();
  }

  void showError(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    );
    Scaffold.of(context).showSnackBar(snackBar);
  }

  void checkRequestSMSanswer(BuildContext context, int answerCode) {
    if (answerCode == 0) {
      setState(() {
        currentStage = _NsgPhoneLoginWidgetState.stageVerification;
        isSMSRequested = false;
      });
    }
    var needRefreshCaptcha = false;
    var errorMessage = '';
    switch (answerCode) {
      case 40101:
        errorMessage = 'You have to get captha first';
        break;
      case 40102:
        errorMessage = 'Captcha is obsolet. Try again!';
        needRefreshCaptcha = true;
        break;
      case 40103:
        errorMessage = 'Captcha text is wrong. Try again!';
        needRefreshCaptcha = true;
        break;
      case 40104:
        errorMessage = 'You have to enter you phone number!';
        break;
      case 40105:
        errorMessage = 'You have to enter captcha text!';
        break;
      default:
        errorMessage = 'Error is occured. Try again!';
    }
    isSMSRequested = false;
    showError(context, errorMessage);

    if (needRefreshCaptcha) {
      refreshCaptcha();
    } else {
      setState(() {
        isSMSRequested = false;
      });
    }
  }

  void doSmsRequest(BuildContext context) {
    if (!_formKey.currentState.validate()) return;
    setState(() {
      isSMSRequested = true;
    });
    widget.provider
        .phoneLoginRequestSMS(phoneNumber, captchaCode)
        .then((value) => checkRequestSMSanswer(context, value))
        .catchError((e) {
      showError(context,
          'Cannot compleate request. Check internet connection and repeate.');
    });
  }

  void refreshCaptcha() {
    isCaptchaLoading = true;
    _loadCaptureImage().then((value) => setState(() {
          captureImage = value;
          isCaptchaLoading = false;
          if (updateTimer != null) {
            updateTimer.cancel();
          }
          secondsLeft = 120;
          updateTimer = Timer.periodic(
              Duration(seconds: 1), (Timer t) => captchaTimer(t));
        }));
  }

  void captchaTimer(Timer timer) {
    if (secondsLeft > 0) {
      setState(() {
        secondsLeft--;
      });
    } else {
      updateTimer.cancel();
      updateTimer = null;
      refreshCaptcha();
    }
  }
}
