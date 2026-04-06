import 'url_updater_stub.dart'
    if (dart.library.html) 'url_updater_web.dart'
    as nsg_url;
import '../shell/nsg_shell.dart';

class NsgNavigator {
  static NsgNavigator instance = NsgNavigator();

  static String? initialRoute;
  static bool useSplashPage = true;

  static bool get isLastPage =>
      (useSplashPage && previousRoute == (initialRoute ?? "/")) ||
      currentRoute == (initialRoute ?? "/");

  static String get currentRoute => NsgShell.navigation.currentRoute;
  static String get previousRoute => NsgShell.navigation.previousRoute;

  static void updateUrlParameters({
    String? id,
    String? widgetId,
    Map<String, String>? parameters,
    bool replace = true,
  }) {
    var arg = _buildParameters(
      id: id,
      widgetId: widgetId,
      parameters: parameters,
    );
    nsg_url.setUrlParams(arg, replace: replace, path: NsgShell.navigation.currentRoute);
  }

  static Future go(
    String pageName, {
    String? id,
    String? widgetId,
    Map<String, String>? parameters,
  }) async {
    await instance.offAndToPage(
      pageName,
      id: id,
      widgetId: widgetId,
      parameters: parameters,
    );
  }

  static Future push(
    String pageName, {
    String? id,
    String? widgetId,
    Map<String, String>? parameters,
  }) async {
    await instance.toPage(
      pageName,
      id: id,
      widgetId: widgetId,
      parameters: parameters,
    );
  }

  static void pop({String? routeIfLast, void Function()? actionIfLast}) {
    instance.back(routeIfLast: routeIfLast, actionIfLast: actionIfLast);
  }

  Future toPage(
    String pageName, {
    String? id,
    String? widgetId,
    Map<String, String>? parameters,
  }) async {
    var arg = _buildParameters(
      id: id,
      widgetId: widgetId,
      parameters: parameters,
    );
    await NsgShell.navigation.toNamed(pageName, parameters: arg);
  }

  Future offAndToPage(
    String pageName, {
    String? id,
    String? widgetId,
    Map<String, String>? parameters,
  }) async {
    var arg = _buildParameters(
      id: id,
      widgetId: widgetId,
      parameters: parameters,
    );
    await NsgShell.navigation.offAndToNamed(pageName, parameters: arg);
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
    NsgShell.navigation.back();
  }

  static Map<String, String> _buildParameters({
    String? id,
    String? widgetId,
    Map<String, String>? parameters,
  }) {
    var arg = <String, String>{};
    if (parameters != null) {
      arg.addAll(parameters);
    }
    if (id != null) {
      arg['id'] = id;
    }
    if (widgetId != null) {
      arg['widgetId'] = widgetId;
    }
    return arg;
  }
}
