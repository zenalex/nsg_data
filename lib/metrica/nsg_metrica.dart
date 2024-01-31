import 'dart:io' as io;

// import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';

class NsgMetrica {
  static bool useYandexMetrica = false;
  static bool useGoogleAnalitics = false;

  ///Активировать использование метрики
  ///useYandex - используем Яндекс.Метрику
  ///useGoodle - используем Гугул.Аналитику
  ///
  ///ВНИМАНИЕ!
  ///В настоящее время использование яндекс метрики отключено
  ///В будущем, подключение различных модулей аналитики должно быть выделено в отделтные пакеты для уменбшения размера сборок
  static void activate({bool useYandex = false, useGoodle = false}) {
    if (kReleaseMode && NsgMetricaOptions.yandexMetricaId.isNotEmpty && !kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) {
      useYandexMetrica = true;
      // AppMetrica.activate(AppMetricaConfig(NsgMetricaOptions.yandexMetricaId));
    }
  }

  static void reportEvent(String event, {Map<String, Object>? map}) {
    if (useYandexMetrica) {
      if (map == null) {
        // AppMetrica.reportEvent(event);
      } else {
        // AppMetrica.reportEventWithMap(event, map);
      }
    }
  }

  static void reportAppStart() {
    if (useYandexMetrica) {
      // AppMetrica.reportEvent('Application start');
    }
  }

  static void reportLoginStart(String loginType) {
    if (useYandexMetrica) {
      // AppMetrica.reportEventWithMap('Login start', {'loginType': loginType});
    }
  }

  static void reportLoginSuccess(String loginType) {
    if (useYandexMetrica) {
      // AppMetrica.reportEventWithMap('Login success', {'loginType': loginType});
    }
  }

  static void reportLoginFailed(String loginType, String errorCode) {
    if (useYandexMetrica) {
      // AppMetrica.reportEventWithMap('Login failed', {'loginType': loginType, 'errorCode': errorCode});
    }
  }

  static void reportToPage(String pageName) {
    if (useYandexMetrica) {
      // AppMetrica.reportEventWithMap('to page', {'pageName': pageName});
    }
  }

  static void reportTableButtonTap(String tableId, String buttonName, {String state = ''}) {
    if (useYandexMetrica && tableId.isNotEmpty) {
      // AppMetrica.reportEventWithMap('table button tap', {'tableId': tableId, 'buttonName': buttonName, 'state': state});
    }
  }
}

class NsgMetricaOptions {
  static String yandexMetricaId = '';
}
