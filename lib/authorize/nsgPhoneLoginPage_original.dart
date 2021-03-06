import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginParams.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginVerificationPage.dart';

import '../nsg_data_provider.dart';

class NsgPhoneLoginPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginParams widgetParams;
  NsgPhoneLoginPage(this.provider, {this.widgetParams}) : super();

  @override
  Widget build(BuildContext context) {
    if (Scaffold.of(context) == null) {
      return Scaffold(
        appBar: widgetParams.appbar ? getAppBar(context) : null,
        //backgroundColor: Colors.white,
        body: NsgPhoneLoginWidget(this, null, provider,
            widgetParams: widgetParams),
      );
    }
    return NsgPhoneLoginWidget(this, null, provider,
        widgetParams: widgetParams);
  }

  AppBar getAppBar(BuildContext context) {
    return AppBar(title: Text(''), centerTitle: true);
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

  Widget background() {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage('lib/assets/titan-back.png'),
          ),
        ),
      ),
    );
  }

  Widget getBackground() {
    var background = Image(
      image: AssetImage('lib/assets/titan-back.png'),
    );
    return background;
  }

  Widget getButtons() {
    return ElevatedButton(
      onPressed: null,
      child: Text('you need to override getButtons'),
    );
  }
}

class NsgPhoneLoginWidget extends StatefulWidget {
  @override
  _NsgPhoneLoginWidgetState createState() => _NsgPhoneLoginWidgetState();

  final NsgPhoneLoginPage loginPage;
  final NsgPhoneLoginVerificationPage verificationPage;
  final NsgPhoneLoginParams widgetParams;
  final NsgDataProvider provider;

  NsgPhoneLoginWidget(this.loginPage, this.verificationPage, this.provider,
      {this.widgetParams})
      : super();
}

class _NsgPhoneLoginWidgetState extends State<NsgPhoneLoginWidget> {
  Image captureImage;
  String phoneNumber = '';
  String captchaCode = '';
  bool isCaptchaLoading = false;
  int currentStage = _NsgPhoneLoginWidgetState.stagePreLogin;
  bool isLoginSuccessfull = false;
  bool isSMSRequested = false;

  PhoneInputFormatter phoneFormatter = PhoneInputFormatter();
  //Осталось секунд до автообновления капчи. Если -1, то капча еще не получена
  //и таймер запускать нет смысла
  int secondsLeft = -1;
  //таймер, запускаемый по факту получения капчи. С автообновлением капчи через 2 минуты
  Timer updateTimer;

  ///Get captcha and send request for SMS
  ///This is first stage of authorization
  static int stagePreLogin = 1;

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

  Widget _getBody(BuildContext context) {
    return Stack(
      fit: StackFit.loose,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: AssetImage('lib/assets/titan-back.png'),
              ),
            ),
          ),
        ),
        Column(
          children: [
            Expanded(
              child: Container(
                //alignment: Alignment.center,
                child: widget.loginPage.getLogo(),
              ),
            ),
            Container(
              //alignment: Alignment.bottomCenter,
              child: _getContext(context),
            ),
          ],
        ),
      ],
    );
  }

  /*Widget _getBody(BuildContext context) {
    return Center(
        child: SingleChildScrollView(
      child: Stack(
        fit: StackFit.loose,
        children: [
          widget.loginPage.background(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20.0),
                      child: widget.loginPage.getLogo(),
                    ),
                  ),
                ],
              ),
              _getContext(context),
            ],
          ),
        ],
      ),
    ));
  }*/

  final _formKey = GlobalKey<FormState>();
  TextEditingController _captchaController;
  Widget _getContext(BuildContext context) {
    if (isLoginSuccessfull) {
      Future.delayed(Duration(seconds: 2))
          .then((e) => Navigator.pop<bool>(context, true));
      return _getContextSuccessful(context);
    }
    _captchaController ??= TextEditingController();
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
                      widget.widgetParams.headerMessageVisible == true
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 5.0),
                              child: Text(
                                widget.widgetParams.headerMessage,
                                style: widget.widgetParams.headerMessageStyle,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : SizedBox(),
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
                        child: Row(
                          children: [
                            Expanded(child: getcaptchaImage()),
                            Column(
                              children: [
                                TextButton(
                                    onPressed: () {
                                      refreshCaptcha();
                                    },
                                    child: Icon(
                                      Icons.refresh,
                                      color: widget.widgetParams.phoneIconColor,
                                      size: widget.widgetParams.buttonSize,
                                    )),
                                Text(secondsLeft.toString())
                              ],
                            ),
                          ],
                        ),
                      ),
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
                                controller: _captchaController,
                                decoration: InputDecoration(
                                    fillColor: widget.widgetParams.fillColor,
                                    hintText:
                                        widget.widgetParams.textEnterCaptcha,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 10.0),
                                    border: InputBorder.none),
                                style: widget.widgetParams.textPhoneField,
                                textCapitalization:
                                    TextCapitalization.characters,
                                onChanged: (value) => captchaCode = value,
                                validator: (value) => captchaCode.length == 6
                                    ? null
                                    : 'Enter captcha code',
                              ),
                            ),
                          ),
                        ),
                      ),
                      /*Padding(
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
                      ),*/
                      widget.loginPage.getButtons(),
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
    Image image;
    try {
      image = await widget.provider.getCaptcha();
    } catch (e) {
      image = Image.asset('lib/assets/no_image.jpg');
    }
    return image;
  }

  void checkRequestSMSanswer(BuildContext context, int answerCode) {
    if (updateTimer != null) {
      updateTimer.cancel();
    }
    if (answerCode == 0) {
      setState(() {
        //currentStage = _NsgPhoneLoginWidgetState.stageVerification;
        isSMSRequested = false;
      });
      gotoNextPage(context);
    }
    var needRefreshCaptcha = false;
    var errorMessage = widget.widgetParams.errorMessageByStatusCode(answerCode);
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
    widget.widgetParams.showError(context, errorMessage);

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
      widget.widgetParams.showError(context,
          'Cannot compleate request. Check internet connection and repeate.');
    });
  }

  void refreshCaptcha() {
    isCaptchaLoading = true;
    _loadCaptureImage().then((value) => setState(() {
          captureImage = value;
          _captchaController.value = TextEditingValue.empty;
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

  void gotoNextPage(BuildContext context) async {
    var result = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (context) => widget.verificationPage));
    if (result ??= false) {
      setState(() {
        isLoginSuccessfull = true;
      });
      if (widget.widgetParams.loginSuccessful != null) {
        widget.widgetParams
            .loginSuccessful(context, widget.widgetParams.parameter);
      }
    } else {
      refreshCaptcha();
    }
  }

  Widget _getContextSuccessful(BuildContext context) {
    return SizedBox(
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
                            Text(
                              'Login successful',
                              style: widget.widgetParams.headerMessageStyle,
                            )
                          ]))
                    ]))));
  }
}
