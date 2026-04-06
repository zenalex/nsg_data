import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum NsgMessagePosition {
  top,
  bottom,
}

abstract class NsgNavigationShell {
  String get currentRoute;
  String get previousRoute;
  Map<String, String?> get parameters;

  Future<T?> toNamed<T>(
    String pageName, {
    Map<String, String>? parameters,
    dynamic arguments,
  });

  Future<T?> offAndToNamed<T>(
    String pageName, {
    Map<String, String>? parameters,
    dynamic arguments,
  });

  void back<T>({T? result});
}

abstract class NsgDialogShell {
  Future<T?> show<T>(
    Widget dialog, {
    bool barrierDismissible = true,
    Color? barrierColor,
  });
}

abstract class NsgMessageShell {
  void showSnackbar({
    required String title,
    required String message,
    bool isDismissible = true,
    Duration? duration,
    Color? backgroundColor,
    Color? colorText,
    Widget? icon,
    double? maxWidth,
    NsgMessagePosition position = NsgMessagePosition.bottom,
  });
}

abstract class NsgEnvironmentShell {
  BuildContext? get context;
  Locale? get locale;
  double get width;
  double get height;

  BuildContext get requireContext {
    final currentContext = context;
    if (currentContext == null) {
      throw StateError('No active shell context is available.');
    }
    return currentContext;
  }
}

class NsgGetXNavigationShell implements NsgNavigationShell {
  const NsgGetXNavigationShell();

  @override
  String get currentRoute => Get.currentRoute;

  @override
  Map<String, String?> get parameters => Get.parameters;

  @override
  String get previousRoute => Get.previousRoute;

  @override
  Future<T?> offAndToNamed<T>(
    String pageName, {
    Map<String, String>? parameters,
    dynamic arguments,
  }) async {
    return Get.offAndToNamed<T>(pageName, parameters: parameters, arguments: arguments);
  }

  @override
  Future<T?> toNamed<T>(
    String pageName, {
    Map<String, String>? parameters,
    dynamic arguments,
  }) async {
    return Get.toNamed<T>(pageName, parameters: parameters, arguments: arguments);
  }

  @override
  void back<T>({T? result}) {
    Get.back<T>(result: result);
  }
}

class NsgGetXDialogShell implements NsgDialogShell {
  const NsgGetXDialogShell();

  @override
  Future<T?> show<T>(
    Widget dialog, {
    bool barrierDismissible = true,
    Color? barrierColor,
  }) async {
    return Get.dialog<T>(
      dialog,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
    );
  }
}

class NsgGetXMessageShell implements NsgMessageShell {
  const NsgGetXMessageShell();

  @override
  void showSnackbar({
    required String title,
    required String message,
    bool isDismissible = true,
    Duration? duration,
    Color? backgroundColor,
    Color? colorText,
    Widget? icon,
    double? maxWidth,
    NsgMessagePosition position = NsgMessagePosition.bottom,
  }) {
    Get.snackbar(
      title,
      message,
      isDismissible: isDismissible,
      duration: duration,
      backgroundColor: backgroundColor,
      colorText: colorText,
      icon: icon,
      maxWidth: maxWidth,
      snackPosition: switch (position) {
        NsgMessagePosition.top => SnackPosition.top,
        NsgMessagePosition.bottom => SnackPosition.bottom,
      },
    );
  }
}

class NsgGetXEnvironmentShell implements NsgEnvironmentShell {
  const NsgGetXEnvironmentShell();

  @override
  BuildContext? get context => Get.context;

  @override
  BuildContext get requireContext {
    final currentContext = context;
    if (currentContext == null) {
      throw StateError('No active GetX context is available.');
    }
    return currentContext;
  }

  @override
  double get height => Get.height;

  @override
  Locale? get locale => Get.locale;

  @override
  double get width => Get.width;
}

class NsgShell {
  static final NsgNavigationShell _defaultNavigation = const NsgGetXNavigationShell();
  static final NsgDialogShell _defaultDialog = const NsgGetXDialogShell();
  static final NsgMessageShell _defaultMessage = const NsgGetXMessageShell();
  static final NsgEnvironmentShell _defaultEnvironment = const NsgGetXEnvironmentShell();

  static NsgNavigationShell navigation = _defaultNavigation;
  static NsgDialogShell dialog = _defaultDialog;
  static NsgMessageShell message = _defaultMessage;
  static NsgEnvironmentShell environment = _defaultEnvironment;

  static void configure({
    NsgNavigationShell? navigation,
    NsgDialogShell? dialog,
    NsgMessageShell? message,
    NsgEnvironmentShell? environment,
  }) {
    if (navigation != null) {
      NsgShell.navigation = navigation;
    }
    if (dialog != null) {
      NsgShell.dialog = dialog;
    }
    if (message != null) {
      NsgShell.message = message;
    }
    if (environment != null) {
      NsgShell.environment = environment;
    }
  }

  static void resetToDefaults() {
    navigation = _defaultNavigation;
    dialog = _defaultDialog;
    message = _defaultMessage;
    environment = _defaultEnvironment;
  }
}
