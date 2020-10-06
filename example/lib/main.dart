import 'package:flutter/material.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginPage.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginParams.dart';
import 'package:nsg_data/nsg_data_provider.dart';
//import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    //S.load(Locale('ru', ''));
    var app = MaterialApp(
        onGenerateTitle: (BuildContext context) => 'NSG_DATA TEST',
        debugShowCheckedModeBanner: false,
        home: MainScreen());
    return app;
  }
}

class MainScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool initialized = false;
  NsgDataProvider provider;
  Image captha;

  @override
  void initState() {
    super.initState();
    if (!initialized) {
      init().then((value) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => NsgPhoneLoginPage(provider,
                  widgetParams: NsgPhoneLoginParams.defaultParams))));
      //setState(() {
      //      initialized = true;
      //    }));
    }
  }

  // Формирование виджета
  @override
  Widget build(BuildContext context) {
    // А вот это вёрстка виджета,
    // немного похоже на QML хотя явно не JSON структура
    return Scaffold(
        backgroundColor: Colors.blue,
        body: Container(
          constraints: BoxConstraints.expand(),
          decoration: BoxDecoration(
            color: Colors.blue,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: getBody(),
            ),
          ),
        ));
  }

  Future init() async {
    provider = NsgDataProvider();
    provider.serverUri = 'http://alex.nsgsoft.ru:5073';
    //await _testAccess();
    await provider.connect();
    print('token ${provider.token}');
    print('is anonymous ${provider.isAnonymous}');
    captha = await provider.getCaptcha();
  }

  String captchaText = '';
  List<Widget> getBody() {
    var list = <Widget>[];
    if (initialized) {
      list.add(Text('INITIALIZED'));
      list.add(Text('isAnonymous = ${provider.isAnonymous}'));
      list.add(Divider());
      list.add(TextField(
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        onChanged: (value) => captchaText = value,
      ));
      list.add(FlatButton(onPressed: () => requestSMS(), child: Text('Login')));

      list.add(captha);
    } else {
      list.add(CircularProgressIndicator());
    }
    return list;
  }

  void requestSMS() {
    provider.phoneLoginRequestSMS('79210000000', captchaText);
  }
}
