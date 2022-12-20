import 'package:get/get.dart';

import 'nsg_middleware.dart';

class NsgGetPage extends GetPage {
  NsgGetPage({
    required super.name,
    required super.page,
    super.binding,
  }) : super(middlewares: [NsgMiddleware.instance]);
}
