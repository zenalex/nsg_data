import 'package:get/get.dart';
import 'url_updater_stub.dart' if (dart.library.html) 'url_updater_web.dart' as nsg_url;

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  static String? initialRoute;
  static bool useSplashPage = true;

  static bool get isLastPage => (useSplashPage && previousRoute == (initialRoute ?? "/")) || currentRoute == (initialRoute ?? "/");

  static String get currentRoute => Get.currentRoute;
  static String get previousRoute => Get.previousRoute;

  static void updateUrlParameters({String? id, String? widgetId, bool replace = true}) {
    var arg = _buildParameters(id: id, widgetId: widgetId);
    nsg_url.setUrlParams(arg, replace: replace, path: Get.currentRoute);
  }

  static Future go(String pageName, {String? id, String? widgetId}) async {
    await instance.offAndToPage(pageName, id: id, widgetId: widgetId);
  }

  static Future push(String pageName, {String? id, String? widgetId}) async {
    await instance.toPage(pageName, id: id, widgetId: widgetId);
  }

  static void pop({String? routeIfLast, void Function()? actionIfLast}) {
    instance.back(routeIfLast: routeIfLast, actionIfLast: actionIfLast);
  }

  Future toPage(String pageName, {String? id, String? widgetId}) async {
    var arg = _buildParameters(id: id, widgetId: widgetId);
    await Get.toNamed(pageName, parameters: arg);
  }

  Future offAndToPage(String pageName, {String? id, String? widgetId}) async {
    var arg = _buildParameters(id: id, widgetId: widgetId);
    await Get.offAndToNamed(pageName, parameters: arg);
  }

  void back({String? routeIfLast, void Function()? actionIfLast}) {
    if (isLastPage) {
      if (routeIfLast != null) {
        go(routeIfLast);
      }
      if (actionIfLast != null) {
        actionIfLast();
      }
      return;
    }
    Get.back();
  }

  static Map<String, String> _buildParameters({String? id, String? widgetId}) {
    var arg = <String, String>{};
    if (id != null) {
      arg['id'] = id;
    }
    if (widgetId != null) {
      arg['widgetId'] = widgetId;
    }
    return arg;
  }
}
