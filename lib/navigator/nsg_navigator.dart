import 'package:get/get.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  Future toPage(String pageName) async {
    return await Get.toNamed(pageName);
  }

  Future offAndToPage(String pageName) async {
    return await Get.offAndToNamed(pageName);
  }
}
