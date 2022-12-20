import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NsgMiddleware extends GetMiddleware {
  static bool isFirstStep = true;
  String initialPage = '';
  bool useDeepLinks = false;
  Map<String, String?>? pageParameters;
  static NsgMiddleware? _instance;
  static NsgMiddleware get instance {
    _instance ??= NsgMiddleware();
    return _instance!;
  }

  static set instance(NsgMiddleware value) {
    _instance = value;
  }

  @override
  RouteSettings? redirect(String? route) {
    if (!useDeepLinks && isFirstStep && initialPage.isNotEmpty) {
      isFirstStep = false;
      return RouteSettings(name: initialPage);
    } else if (isFirstStep) {
      pageParameters = Get.parameters;
      initialBinding(route);
      return RouteSettings(name: initialPage);
    }
    return super.redirect(route);
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    return page;
  }

  void initialBinding(String? route) {
    isFirstStep = false;
  }
}
