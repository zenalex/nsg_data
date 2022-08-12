import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nsg_data/nsg_data_provider.dart';

import '../models/nsgLoginModel.dart';
import 'nsgPhoneLoginParams.dart';

class NsgPhoneLoginVerificationPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginParams? widgetParams;

  NsgPhoneLoginVerificationPage(this.provider, {this.widgetParams}) : super();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widgetParams!.appbar! ? getAppBar(context) : null,
      //backgroundColor: Colors.white,
      body: NsgPhoneLoginVerificationWidget(this, provider, widgetParams: widgetParams),
    );
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

  Image getBackground() {
    var background = Image.asset(
      'lib/assets/titan-back.png',
      repeat: ImageRepeat.repeat,
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

class NsgPhoneLoginVerificationWidget extends StatefulWidget {
  final NsgPhoneLoginParams? widgetParams;
  final NsgDataProvider provider;
  final NsgPhoneLoginVerificationPage verificationPage;

  NsgPhoneLoginVerificationWidget(this.verificationPage, this.provider, {this.widgetParams}) : super();
  @override
  State<StatefulWidget> createState() => _NsgPhoneLoginVerificationState();
}

class _NsgPhoneLoginVerificationState extends State<NsgPhoneLoginVerificationWidget> {
  Timer? updateTimer;
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
    updateTimer ??= updateTimer = Timer.periodic(Duration(seconds: 1), (Timer t) => updateTimerEvent(t));
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20.0)),
          boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.15), offset: Offset(0.0, 4.0), blurRadius: 4.0, spreadRadius: 2.0)],
        ),
        margin: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        padding: EdgeInsets.all(15.0),
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
                          padding: EdgeInsets.symmetric(vertical: 5.0),
                          child: Text(
                            widget.widgetParams!.headerMessage,
                            style: widget.widgetParams!.headerMessageStyle,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SizedBox(),
                  SizedBox(height: widget.widgetParams!.headerMessageVisible == true ? 5.0 : 0.0),
                  Text(
                    widget.widgetParams!.headerMessageVerification,
                    style: widget.widgetParams!.headerMessageStyle,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15.0),
                  Text(
                    widget.widgetParams!.interpolate(widget.widgetParams!.descriptionMessegeVerification, params: {'phone': widget.provider.phoneNumber}),
                    style: widget.widgetParams!.descriptionStyle,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15.0),
                  Container(
                    decoration: BoxDecoration(
                      color: widget.widgetParams!.phoneFieldColor,
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        style: widget.widgetParams!.textPhoneField,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                        ),
                        onChanged: (text) {
                          securityCode = text;
                          if (securityCode.length == 6) {
                            checkSecurityCode(context, securityCode);
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 15.0),
                  widget.verificationPage.getButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void checkSecurityCode(BuildContext context, String securityCode) {
    setState(() {
      isBusy = true;
    });
    widget.provider.phoneLogin(widget.provider.phoneNumber, securityCode).then((result) => checkLoginResult(context, result));
    setState(() {
      isBusy = false;
    });
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
      Get.back<bool>(result: true);
    }
  }

  Future showError(String errorMessage, bool needEnterCaptcha) async {
    widget.widgetParams!.showError(context, errorMessage);
    if (needEnterCaptcha) {
      stopTimer();
      setState(() {
        isBusy = true;
      });
      await Future.delayed(Duration(seconds: 3));
      Get.back<bool>(result: false);
    }
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
