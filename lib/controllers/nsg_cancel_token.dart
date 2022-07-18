import 'package:dio/dio.dart';
import 'package:nsg_data/helpers/nsg_data_guid.dart';

class NsgCancelToken {
  String id = Guid.newGuid();
  bool isCalceled = false;
  CancelToken dioCancelToken = CancelToken();
  void calcel() {
    isCalceled = true;
    dioCancelToken.cancel();
  }
}
