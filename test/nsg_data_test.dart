import 'package:nsg_data/nsg_data_client.dart';
import 'package:nsg_data/nsg_data_request.dart';

import '../example/newsItem.dart';

void main() {
  print('started');
  init().then((value) => print('successful')).catchError((e) {
    print("Got error: ${e.error}"); // Finally, callback fires.
    return true; // Future completes with 42.
  }).whenComplete(() => print('compleated'));
  print('finished');
}

Future init() async {
  NsgDataClient.client.registerDataItem(NewsItem());
  print('request start');
  var request = await NsgDataRequest<NewsItem>().requestItems();
  print('request finished');
  request.items.forEach((element) {
    print('date = ${element.date}, title = ${element.title}');
  });
}
