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
      if (map == null) {
        // NsgMetrica.instance!.reportEvent(event);
      } else {
        // AppMetrica.reportEventWithMap(event, map);
      }
    }
  }

  static void reportAppStart() {
    // AppMetrica.reportEvent('Application start');
  }

  static void reportLoginStart(String loginType) {
    // AppMetrica.reportEventWithMap('Login start', {'loginType': loginType});
  }

  static void reportLoginSuccess(String loginType) {
    // AppMetrica.reportEventWithMap('Login success', {'loginType': loginType});
  }

  static void reportLoginFailed(String loginType, String errorCode) {
    // AppMetrica.reportEventWithMap('Login failed', {'loginType': loginType, 'errorCode': errorCode});
  }

  static void reportToPage(String pageName) {
    // AppMetrica.reportEventWithMap('to page', {'pageName': pageName});
  }

  static void reportTableButtonTap(String tableId, String buttonName, {String state = ''}) {
    // AppMetrica.reportEventWithMap('table button tap', {'tableId': tableId, 'buttonName': buttonName, 'state': state});
  }

