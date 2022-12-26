import 'dart:io' as io;

import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';

class NsgMetrica {
  static bool useYandexMetrica = false;

  static void activate() {
    if (NsgMetricaOptions.yandexMetricaId.isNotEmpty && !kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) {
      useYandexMetrica = true;
      AppMetrica.activate(AppMetricaConfig(NsgMetricaOptions.yandexMetricaId));
    }
  }

  static void reportEvent(String event) {
    if (useYandexMetrica) {
      AppMetrica.reportEvent(event);
    }
  }

  static void reportAppStart() {
    if (useYandexMetrica) {
      AppMetrica.reportEvent('Application start');
    }
  }

  static void reportLoginStart(String loginType) {
    if (useYandexMetrica) {
      AppMetrica.reportEventWithMap('Login start', {'loginType': loginType});
    }
  }

  static void reportLoginSuccess(String loginType) {
    if (useYandexMetrica) {
      AppMetrica.reportEventWithMap('Login success', {'loginType': loginType});
    }
  }

  static void reportLoginFailed(String loginType, String errorCode) {
    if (useYandexMetrica) {
      AppMetrica.reportEventWithMap('Login failed', {'loginType': loginType, 'errorCode': errorCode});
    }
  }

  static void reportToPage(String pageName) {
    if (useYandexMetrica) {
      AppMetrica.reportEventWithMap('to page', {'pageName': pageName});
    }
  }
}

class NsgMetricaOptions {
  static String yandexMetricaId = '';
}
