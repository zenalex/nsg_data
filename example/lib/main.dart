import 'package:example/model/cardItem.dart';
import 'package:example/model/cityItem.dart';
import 'package:flutter/material.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginPage.dart';
import 'package:nsg_data/authorize/nsgPhoneLoginParams.dart';
import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_provider.dart';
import 'package:nsg_data/nsg_data_request.dart';

import 'model/UserSettings.dart';
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
    init(context);
  }

  void loginSuccessful(BuildContext context, dynamic parameter) {
    Navigator.pop<bool>(context, true);
  }

  void loginResult(bool loginResult) {
    loginResult ??= false;
    setState(() {
      initialized = true;
      isLoginSuccessful = loginResult;
    });
    loadData();
  }

  Future loadData() async {
    List<UserSettingsItem> items;
    items = (await NsgDataRequest<UserSettingsItem>().requestItems());
    if (items == null || items == null || items.isEmpty) {
      return;
    }
    var userSettingsItem = items[0];
    await NsgDataRequest()
        .loadAllReferents([userSettingsItem], [UserSettingsItem.name_cityId]);
    //var city = await userSettingsItem.cityAsync();
    var city = userSettingsItem.city;
    if (city != null) {
      print('My city name = ' + city.title);
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

  Future init(BuildContext context) async {
    if (provider != null) {
      return;
    }
    provider = NsgDataProvider();
    provider.serverUri = 'http://alex.nsgsoft.ru:5073';

    NsgDataClient.client
        .registerDataItem(UserSettingsItem(), remoteProvider: provider);
    NsgDataClient.client.registerDataItem(CardItem(), remoteProvider: provider);
    NsgDataClient.client.registerDataItem(CityItem(), remoteProvider: provider);

    await provider.connect();

    if (provider.isAnonymous) {
      NsgPhoneLoginParams.defaultParams.loginSuccessful = loginSuccessful;
      await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (context) => NsgPhoneLoginPage(provider,
                      widgetParams: NsgPhoneLoginParams.defaultParams)))
          .then((value) => loginResult(value));
    } else {
      await loadData();
    }
    return;
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
