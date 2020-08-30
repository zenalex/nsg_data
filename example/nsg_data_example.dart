import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_request.dart';
import 'package:nsg_data/nsg_data_request_filter.dart';

import 'newsItem.dart';

void main() {
  print('started');
  init().then((value) => print('successful')).catchError((e) {
    print("Got error: ${e.error}");
  }).whenComplete(() => print('compleated'));
  print('finished');
}

Future init() async {
  NsgDataClient.client.registerDataItem(NewsItem());
  print('request start');
  var filter = NsgDataRequestFilter(top: 10, count: 25);
  var request = await NsgDataRequest<NewsItem>().requestItems(filter: filter);
  print('request finished. Count = ${request.items.length}');
  request.items.forEach((element) {
    print(
        'id = ${element.id}, date = ${element.date}, title = ${element.title}');
  });
}
