import 'package:nsg_data/controllers/nsgBaseController.dart';

class NsgDefaultController extends NsgBaseController {
  NsgDefaultController({required super.dataType}) : super() {
    requestOnInit = false;
    lateInit = true;
  }
}
