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
  bool isLoginSuccessful = false;
  NsgDataProvider provider;
  Image captha;

  @override
  void initState() {
    super.initState();
    if (!initialized) {
      NsgPhoneLoginParams.defaultParams.loginSuccessful = loginSuccessful;
      init().then((value) => Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (context) => NsgPhoneLoginPage(provider,
                      widgetParams: NsgPhoneLoginParams.defaultParams)))
          .then((value) => loginResult(value)));
      //setState(() {
      //      initialized = true;
      //    }));
    }
  }

  void loginSuccessful() {
    Navigator.pop<bool>(context, true);
  }

  void loginResult(bool loginResult) {
    loginResult ??= false;
    setState(() {
      initialized = true;
      isLoginSuccessful = loginResult;
    });
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
    await provider.connect();
    print('token ${provider.token}');
    print('is anonymous ${provider.isAnonymous}');
  }

  String captchaText = '';
  List<Widget> getBody() {
    var list = <Widget>[];
    if (initialized) {
      list.add(Text('is login successful = $isLoginSuccessful'));
      list.add(Text('isAnonymous = ${provider.isAnonymous}'));
      list.add(Divider());
    } else {
      list.add(CircularProgressIndicator());
    }
    return list;
  }
}
