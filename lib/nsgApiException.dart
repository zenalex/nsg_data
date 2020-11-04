import 'package:nsg_data/nsgDataApiError.dart';

class NsgApiException implements Exception {
  final NsgApiError error;
  NsgApiException(this.error);
}
