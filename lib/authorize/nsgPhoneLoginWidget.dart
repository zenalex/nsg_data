import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginWidgetParams.dart';

import '../nsg_data_provider.dart';

class NsgPhoneLoginWidget extends StatefulWidget {
  @override
  _NsgPhoneLoginWidgetState createState() => _NsgPhoneLoginWidgetState();

  final NsgPhoneLoginWidgetParams widgetParams;
  final NsgDataProvider provider;

  NsgPhoneLoginWidget(this.provider, {this.widgetParams}) : super();
}

class _NsgPhoneLoginWidgetState extends State<NsgPhoneLoginWidget> {
  Image captureImage;

  @override
  void initState() {
    super.initState();
    if (captureImage == null) {
      _loadCaptureImage().then((value) => setState(() {
            captureImage = value;
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
                        widget.widgetParams.textMessage,
                        style: widget.widgetParams.textMessageStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        widget.widgetParams.textDescription,
                        style: widget.widgetParams.textDescriptionStyle,
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
                          padding: EdgeInsets.only(right: 15.0),
                          child: TextFormField(
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            style: widget.widgetParams.textPhoneField,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 5.0, vertical: 10.0),
                              prefixIcon: Icon(
                                Icons.smartphone,
                                size: widget.widgetParams.iconSize,
                                color: widget.widgetParams.phoneIconColor,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: getcaptureImage()),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 5.0),
                      child: Container(
                        height: widget.widgetParams.buttonSize,
                        width: double.infinity,
                        child: TextFormField(
                          decoration: InputDecoration(
                              fillColor: widget.widgetParams.textColor,
                              labelText: widget.widgetParams.textEnterCaptcha),
                          //elevation: 0.0,
                          //shape: RoundedRectangleBorder(
                          //  borderRadius: BorderRadius.circular(5.0),
                          //side: BorderSide(
                          //color: widget.widgetParams.color0,
                          //),
                          //),
                          style: widget.widgetParams.textMessageStyle,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            side: BorderSide(
                              color: widget.widgetParams.sendSmsBorderColor,
                            ),
                          ),
                          onPressed: () {},
                          child: Text(
                            widget.widgetParams.textSendSms,
                            style: widget.widgetParams.textMessageStyle,
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

  Widget getcaptureImage() {
    if (captureImage == null) {
      return Icon(Icons.hourglass_empty, color: widget.widgetParams.textColor);
    }
    return captureImage;
  }

  ///Get captcha from server
  Future<Image> _loadCaptureImage() async {
    return await widget.provider.getCaptcha();
  }
}
