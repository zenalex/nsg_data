import 'package:get/get.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  static Future go(String pageName) async {
    await instance.offAndToPage(pageName);
  }

  static Future push(String pageName) async {
    await instance.toPage(pageName);
  }

  static void pop() {
    instance.back();
  }

  Future toPage(String pageName) async {
    await Get.toNamed(pageName);
  }

  Future offAndToPage(String pageName) async {
    await Get.offAndToNamed(pageName);
  }

  void back() {
    Get.back();
  }
}
