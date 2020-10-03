import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data_provider.dart';

import 'nsgPhoneLoginPageParams.dart';

class NsgPhoneLoginVerificationPage extends StatelessWidget {
  final NsgDataProvider provider;
  final NsgPhoneLoginWidgetParams widgetParams;
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
  final NsgPhoneLoginWidgetParams widgetParams;
  final NsgDataProvider provider;

  NsgPhoneLoginVerificationWidget(this.provider, {this.widgetParams}) : super();
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    throw UnimplementedError();
  }
}
