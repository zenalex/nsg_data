import 'package:flutter/material.dart';
import 'package:nsg_data/nsg_data_provider.dart';

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
      home: MainScreen(),
    );
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

  @override
  void initState() {
    super.initState();
    if (!initialized) {
      init().then((value) => setState(() {
            initialized = true;
          }));
    }
    ;
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
    provider.serverUri = 'https://alex.nsgsoft.ru:5073';
    await provider.connect();
    print('token ${provider.token}');
    print('is anonymous ${provider.isAnonymous}');
  }

  List<Widget> getBody() {
    var list = <Widget>[];
    if (initialized) {
      list.add(Text('INITIALIZED'));
      list.add(Text('isAnonymous = ${provider.isAnonymous}'));
    } else {
      list.add(CircularProgressIndicator());
    }
    return list;
  }
}
