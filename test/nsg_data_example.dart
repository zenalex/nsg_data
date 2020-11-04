import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_provider.dart';
import 'package:nsg_data/nsg_data_request.dart';

import 'UserSettings.dart';
import 'cardItem.dart';
import 'newsItem.dart';

void main() {
  print('started');
  init().then((value) => print('successful')).catchError((e) {
    print('Got error: ${e.error}');
  }).whenComplete(() => print('compleated'));
  print('finished');
}

Future init() async {
  var provider = NsgDataProvider();
  provider.serverUri = 'http://192.168.1.20:5073';
  NsgDataClient.client
      .registerDataItem(UserSettingsItem(), remoteProvider: provider);
  NsgDataClient.client.registerDataItem(NewsItem(), remoteProvider: provider);
  NsgDataClient.client.registerDataItem(CardItem(), remoteProvider: provider);

  var userSettings;
  (await NsgDataRequest<UserSettingsItem>().requestItems())
      .fold((e) => print(e), (items) => userSettings = items[0]);
  print(userSettings.userId);
  var myCountry = userSettings.country;
  print(myCountry.title);

  /*print('request start');
  var filter = NsgDataRequestFilter(top: 10, count: 25);
  var request = await NsgDataRequest<NewsItem>().requestItems(filter: filter);
  print('request News finished. Count = ${request.items.length}');
  request.items.forEach((element) {
    print(
        'id = ${element.id}, date = ${element.date}, title = ${element.title}');
  });

  var requestCard =
      await NsgDataRequest<CardItem>().requestItems(filter: filter);
  print('request Card finished. Count = ${request.items.length}');
  requestCard.items.forEach((element) {
    print('id = ${element.id}, activated = ${element.activated}');
  });*/
}
