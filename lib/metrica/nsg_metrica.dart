class NsgMetrica {
  ///ВНИМАНИЕ!
  ///Используем гугл аналитикс, так как он реализован для большего числа платформ
  ///В настоящее время использование яндекс метрики отключено
  ///В будущем, подключение различных модулей аналитики должно быть выделено в отделтные пакеты для уменбшения размера сборок
  // static void activate() {
  //   if (kReleaseMode && NsgMetricaOptions.yandexMetricaId.isNotEmpty && !kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) {
  //     useYandexMetrica = true;
  //     // AppMetrica.activate(AppMetricaConfig(NsgMetricaOptions.yandexMetricaId));
  //   }
  // }
  static NsgMetrica? instance;

  static void reportEvent(String event, {Map<String, Object>? map}) {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportEvent(event, map: map);
    }
  }

  static void reportAppStart() {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportAppStart();
    }
  }

  static void reportLoginStart(String loginType) {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportLoginStart(loginType);
    }
  }

  static void reportLoginSuccess(String loginType) {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportLoginSuccess(loginType);
    }
  }

  static void reportLoginFailed(String loginType, String errorCode) {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportLoginFailed(loginType, errorCode);
    }
  }

  static void reportToPage(String pageName) {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportToPage(pageName);
    }
  }

  static void reportTableButtonTap(String tableId, String buttonName, {String state = ''}) {
    if (NsgMetrica.instance != null) {
      NsgMetrica.instance!.sendReportTableButtonTap(tableId, buttonName, state: state);
    }
  }

  void sendReportEvent(String event, {Map<String, Object>? map}) {
    // if (NsgMetrica.instance != null) {
    //   if (map == null) {
    //     // NsgMetrica.instance!.reportEvent(event);
    //   } else {
    //     // AppMetrica.reportEventWithMap(event, map);
    //   }
    // }
  }

  void sendReportAppStart() {
    // AppMetrica.reportEvent('Application start');
  }

  void sendReportLoginStart(String loginType) {
    // AppMetrica.reportEventWithMap('Login start', {'loginType': loginType});
  }

  void sendReportLoginSuccess(String loginType) {
    // AppMetrica.reportEventWithMap('Login success', {'loginType': loginType});
  }

  void sendReportLoginFailed(String loginType, String errorCode) {
    // AppMetrica.reportEventWithMap('Login failed', {'loginType': loginType, 'errorCode': errorCode});
  }

  void sendReportToPage(String pageName) {
    // AppMetrica.reportEventWithMap('to page', {'pageName': pageName});
  }

  void sendReportTableButtonTap(String tableId, String buttonName, {String state = ''}) {
    // AppMetrica.reportEventWithMap('table button tap', {'tableId': tableId, 'buttonName': buttonName, 'state': state});
  }
}
