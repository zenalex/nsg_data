import 'package:nsg_data/nsg_data_provider.dart';

void main() async {
  print('started init');

  await init();

  print('finished init');
}

Future init() async {
  var provider = NsgDataProvider();
  provider.serverUri = 'http://192.168.1.20:5073';
  await provider.connect();
  print('token ${provider.token}');
  print('is anonymous ${provider.isAnonymous}');
}
