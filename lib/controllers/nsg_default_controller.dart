import 'package:nsg_data/controllers/nsgBaseController.dart';
import 'package:nsg_data/nsg_data_requestParams.dart';

class NsgDefaultController extends NsgBaseController {
  NsgDefaultController({required super.dataType, super.controllerMode}) : super() {
    requestOnInit = false;
    lateInit = true;
  }

  @override
  NsgDataRequestParams get getRequestFilter {
    return super.getRequestFilter;
  }
}
