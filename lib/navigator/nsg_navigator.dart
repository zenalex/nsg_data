import 'package:get/get.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

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
