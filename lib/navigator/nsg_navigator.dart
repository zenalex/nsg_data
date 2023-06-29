import 'package:get/get.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  static void go(String pageName) {
    instance.offAndToPage(pageName);
  }

  static void push(String pageName) {
    instance.toPage(pageName);
  }

  static void pop() {
    instance.back();
  }

  void toPage(String pageName) {
    Get.toNamed(pageName);
  }

  void offAndToPage(String pageName) {
    Get.offAndToNamed(pageName);
  }

  void back() {
    Get.back();
  }
}
