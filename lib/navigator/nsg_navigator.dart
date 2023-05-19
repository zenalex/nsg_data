import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  void toPage(BuildContext context, String pageName) {
    GoRouter.of(context).push(pageName);
  }

  void offAndToPage(BuildContext context, String pageName) {
    GoRouter.of(context).push(pageName);
    //Get.offAndToNamed(pageName);
  }

  void back(BuildContext context) {
    if (context.mounted) {
      GoRouter.of(context).pop();
    }
    //Get.back();
  }

  Future toLoginPage() async {
    throw Exception('toLoginPage is NOT IMPLEMENTED');
  }
}
