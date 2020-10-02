import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginPageParams.dart';

import '../nsg_data_provider.dart';

class NsgPhoneLoginPage extends StatefulWidget {
  @override
  _NsgPhoneLoginWidgetState createState() => _NsgPhoneLoginWidgetState();

  final NsgPhoneLoginWidgetParams widgetParams;
  final NsgDataProvider provider;

  NsgPhoneLoginPage(this.provider, {this.widgetParams}) : super();
}

class _NsgPhoneLoginWidgetState extends State<NsgPhoneLoginPage> {
  Image captureImage;
  String phoneNumber = '';
  String captchaCode = '';
  bool isCaptchaLoading = false;
  int currentStage = _NsgPhoneLoginWidgetState.stagePreLogin;
  bool isSMSRequested = false;

  ///Get captcha and send request for SMS
  ///This is first stage of authorization
  static int stagePreLogin = 1;

  ///After SMS is recieved, send verification code to the server.
  ///This is the last stage of authorization
  static int stageVerification = 2;

  @override
  void initState() {
    super.initState();
    isCaptchaLoading = true;
    if (captureImage == null) {
      _loadCaptureImage().then((value) => setState(() {
            captureImage = value;
            isCaptchaLoading = false;
          }));
    }
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

  Widget _getContext(BuildContext context) {
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
                            inputFormatters: [PhoneInputFormatter()],
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
                          ),
                        ),
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(children: [
                          Expanded(child: getcaptchaImage()),
                          TextButton(
                            child: Icon(
                              Icons.refresh,
                              color: widget.widgetParams.phoneIconColor,
                              size: widget.widgetParams.buttonSize,
                            ),
                            onPressed: () {
                              setState(() {
                                isCaptchaLoading = true;
                              });
                              _loadCaptureImage().then((value) => setState(() {
                                    captureImage = value;
                                    isCaptchaLoading = false;
                                  }));
                            },
                          )
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
                              : () {
                                  setState(() {
                                    isSMSRequested = true;
                                  });
                                  widget.provider
                                      .phoneLoginRequestSMS(
                                          phoneNumber, captchaCode)
                                      .then((value) => setState(() {
                                            currentStage =
                                                _NsgPhoneLoginWidgetState
                                                    .stageVerification;
                                            isSMSRequested = false;
                                          }));
                                },
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
}
