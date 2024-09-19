import 'package:get/get.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  static Future go(String pageName, {String? id}) async {
    await instance.offAndToPage(pageName, id: id);
  }

  static Future push(String pageName, {String? id}) async {
    await instance.toPage(pageName, id: id);
  }

  static void pop() {
    instance.back();
  }

  Future toPage(String pageName, {String? id}) async {
    var arg = <String, String>{};
    if (id != null) {
      arg['id'] = id;
    }
    await Get.toNamed(pageName, parameters: arg);
  }

  Future offAndToPage(String pageName, {String? id}) async {
    var arg = <String, String>{};
    if (id != null) {
      arg['id'] = id;
    }
    await Get.offAndToNamed(pageName, parameters: arg);
  }

  void back() {
    Get.back();
  }
}
