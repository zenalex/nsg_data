import 'package:get/get.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  static Future go(String pageName, {String? id, String? widgetId}) async {
    await instance.offAndToPage(pageName, id: id, widgetId: widgetId);
  }

  static Future push(String pageName, {String? id, String? widgetId}) async {
    await instance.toPage(pageName, id: id, widgetId: widgetId);
  }

  static void pop() {
    instance.back();
  }

  Future toPage(String pageName, {String? id, String? widgetId}) async {
    var arg = <String, String>{};
    if (id != null) {
      arg['id'] = id;
    }
    if (widgetId != null) {
      arg['widgetId'] = widgetId;
    }
    await Get.toNamed(pageName, parameters: arg);
  }

  Future offAndToPage(String pageName, {String? id, String? widgetId}) async {
    var arg = <String, String>{};
    if (id != null) {
      arg['id'] = id;
    }
    if (widgetId != null) {
      arg['widgetId'] = widgetId;
    }
    await Get.offAndToNamed(pageName, parameters: arg);
  }

  void back() {
    Get.back();
  }
}
