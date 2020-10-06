import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data_provider.dart';

import 'nsgPhoneLoginParams.dart';

class NsgPhoneLoginVerificationPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginParams widgetParams;

  NsgPhoneLoginVerificationPage(this.provider, {this.widgetParams}) : super();

  @override
  Widget build(BuildContext context) {
    if (Scaffold.of(context, nullOk: true) == null) {
      return Scaffold(
        backgroundColor: Colors.blue,
        body: NsgPhoneLoginVerificationWidget(provider,
            widgetParams: widgetParams),
      );
    }
    return NsgPhoneLoginVerificationWidget(provider,
        widgetParams: widgetParams);
  }
}

class NsgPhoneLoginVerificationWidget extends StatefulWidget {
  final NsgPhoneLoginParams widgetParams;
  final NsgDataProvider provider;

  NsgPhoneLoginVerificationWidget(this.provider, {this.widgetParams}) : super();
  @override
  State<StatefulWidget> createState() => _NsgPhoneLoginVerificationState();
}

class _NsgPhoneLoginVerificationState
    extends State<NsgPhoneLoginVerificationWidget> {
  Timer updateTimer;
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
    updateTimer ??= updateTimer =
        Timer.periodic(Duration(seconds: 1), (Timer t) => updateTimerEvent(t));
  }

  void stopTimer() {
    if (updateTimer != null) {
      updateTimer.cancel();
      updateTimer = null;
    }
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
  String securityCode = '';
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
                            widget.widgetParams.headerMessageVerification,
                            style: widget.widgetParams.headerMessageStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            widget.widgetParams.interpolate(
                                widget.widgetParams
                                    .descriptionMessegeVerification,
                                params: {'phone': widget.provider.phoneNumber}),
                            style: widget.widgetParams.descriptionStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 5.0),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 5.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.widgetParams.phoneFieldColor,
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(right: 15),
                              child: TextFormField(
                                keyboardType: TextInputType.number,
                                style: widget.widgetParams.textPhoneField,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15.0, vertical: 15.0),
                                  prefixIcon: Icon(
                                    Icons.vpn_key,
                                    size: widget.widgetParams.iconSize,
                                    color: widget.widgetParams.phoneIconColor,
                                  ),
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
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 5.0),
                          child: Container(
                            height: widget.widgetParams.buttonSize,
                            width: double.infinity,
                            child: RaisedButton(
                              elevation: 0.0,
                              color: widget.widgetParams.sendSmsButtonColor,
                              disabledColor:
                                  widget.widgetParams.disableButtonColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                                side: BorderSide(
                                  color: widget.widgetParams.sendSmsBorderColor,
                                ),
                              ),
                              onPressed: (isBusy || secondsRepeateLeft > 0)
                                  ? null
                                  : () {},
                              child: Text(
                                widget.widgetParams.textResendSms +
                                    ' ($secondsRepeateLeft)',
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
        ));
  }

  void checkSecurityCode(BuildContext context, String securityCode) {
    setState(() {
      isBusy = true;
    });
    widget.provider
        .phoneLogin(widget.provider.phoneNumber, securityCode)
        .then((result) => checkLoginResult(context, result));
    setState(() {
      isBusy = false;
    });
  }

  void checkLoginResult(BuildContext context, int statusCode) {
    if (statusCode == 0) {
      print('sucessful login.');
      Navigator.pop(context, true);
    } else {
      var needEnterCaptcha = (statusCode != 40300);
      var errorMessage =
          widget.widgetParams.errorMessageByStatusCode(statusCode);
      showError(context, errorMessage, needEnterCaptcha);
    }
  }

  Future showError(
      BuildContext context, String errorMessage, bool needEnterCaptcha) async {
    widget.widgetParams.showError(context, errorMessage);
    if (needEnterCaptcha) {
      stopTimer();
      setState(() {
        isBusy = true;
      });
      await Future.delayed(Duration(seconds: 3));
      Navigator.pop(context, false);
    }
  }

  void updateTimerEvent(Timer t) {
    if (widget.provider.smsRequestedTime == null) {
      stopTimer();
    }
    setState(() {
      secondsRepeateLeft = 120 -
          DateTime.now().difference(widget.provider.smsRequestedTime).inSeconds;
      secondsRepeateLeft = secondsRepeateLeft < 0 ? 0 : secondsRepeateLeft;
    });
  }
}
