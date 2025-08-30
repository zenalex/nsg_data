import 'package:web/web.dart' as web;

/// Утилиты для работы с URL в веб-приложениях Flutter
class UrlUtils {
  /// Получить полный URL страницы
  static String getCurrentUrl() {
    return web.window.location.href;
  }

  /// Получить origin (протокол + домен + порт)
  static String getCurrentOrigin() {
    return web.window.location.origin;
  }

  /// Получить hostname (домен)
  static String getCurrentHostname() {
    return web.window.location.hostname;
  }

  /// Получить pathname (путь после домена)
  static String getCurrentPathname() {
    return web.window.location.pathname;
  }

  /// Получить search параметры (?param1=value1&param2=value2)
  static String getCurrentSearch() {
    return web.window.location.search;
  }

  /// Получить hash (#anchor)
  static String getCurrentHash() {
    return web.window.location.hash;
  }

  /// Получить referrer (откуда пришли на сайт)
  static String getReferrer() {
    return web.document.referrer;
  }

  /// Проверить, является ли URL безопасным (HTTPS)
  static bool isSecureUrl() {
    return web.window.location.protocol == 'https:';
  }

  /// Получить базовый URL без параметров
  static String getBaseUrl() {
    final location = web.window.location;
    return '${location.protocol}//${location.host}${location.pathname}';
  }

  /// Получить порт
  static String getPort() {
    return web.window.location.port;
  }

  /// Получить протокол
  static String getProtocol() {
    return web.window.location.protocol;
  }

  /// Вывести всю информацию о URL в консоль
  static void printUrlInfo() {
    print('=== ИНФОРМАЦИЯ О URL ===');
    print('Полный URL: ${getCurrentUrl()}');
    print('Origin: ${getCurrentOrigin()}');
    print('Hostname: ${getCurrentHostname()}');
    print('Port: ${getPort()}');
    print('Protocol: ${getProtocol()}');
    print('Pathname: ${getCurrentPathname()}');
    print('Search: ${getCurrentSearch()}');
    print('Hash: ${getCurrentHash()}');
    print('Referrer: ${getReferrer()}');
    print('Безопасный (HTTPS): ${isSecureUrl()}');
    print('Base URL: ${getBaseUrl()}');
    print('========================');
  }
}

/// Класс для работы с URL параметрами
class UrlParams {
  /// Получить все параметры запроса как Map
  static Map<String, String> getQueryParameters() {
    final search = UrlUtils.getCurrentSearch();
    if (search.isEmpty || !search.startsWith('?')) return {};

    final params = <String, String>{};
    final query = search.substring(1); // Убираем '?'
    final pairs = query.split('&');

    for (final pair in pairs) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        final key = Uri.decodeComponent(parts[0]);
        final value = Uri.decodeComponent(parts[1]);
        params[key] = value;
      }
    }

    return params;
  }

  /// Получить значение параметра по ключу
  static String? getQueryParameter(String key) {
    return getQueryParameters()[key];
  }

  /// Проверить наличие параметра
  static bool hasQueryParameter(String key) {
    return getQueryParameters().containsKey(key);
  }

  /// Получить все параметры как строку для логирования
  static String getQueryParametersString() {
    final params = getQueryParameters();
    if (params.isEmpty) return 'нет параметров';

    return params.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }
}

/// Примеры использования
class UrlExamples {
  static void exampleUsage() {
    // Получить текущий URL
    final currentUrl = UrlUtils.getCurrentUrl();
    print('Текущий URL: $currentUrl');

    // Проверить, безопасное ли соединение
    final isSecure = UrlUtils.isSecureUrl();
    print('HTTPS: $isSecure');

    // Получить параметры из URL
    final params = UrlParams.getQueryParameters();
    final userId = UrlParams.getQueryParameter('userId');
    final sessionId = UrlParams.getQueryParameter('session');
    print('Все параметры: $params');
    print('User ID: $userId');
    print('Session ID: $sessionId');

    // Получить referrer
    final referrer = UrlUtils.getReferrer();
    print('Пришли с сайта: ${referrer.isEmpty ? 'прямой заход' : referrer}');

    // Проверить наличие определенных параметров
    if (UrlParams.hasQueryParameter('utm_source')) {
      print('Есть UTM метка: ${UrlParams.getQueryParameter('utm_source')}');
    }

    // Вывести всю информацию
    UrlUtils.printUrlInfo();
  }

  static void logUserJourney() {
    final referrer = UrlUtils.getReferrer();
    final currentUrl = UrlUtils.getCurrentUrl();
    final params = UrlParams.getQueryParametersString();

    print('=== АНАЛИЗ ПОЛЬЗОВАТЕЛЬСКОГО ПУТИ ===');
    print('Текущая страница: $currentUrl');
    print('Источник: ${referrer.isEmpty ? 'Прямой заход или закладки' : referrer}');
    print('Параметры: $params');

    // Анализ источника трафика
    if (referrer.contains('google.com')) {
      print('Источник: Google');
    } else if (referrer.contains('yandex.ru')) {
      print('Источник: Yandex');
    } else if (referrer.contains('facebook.com')) {
      print('Источник: Facebook');
    } else if (referrer.isEmpty) {
      print('Источник: Прямой заход');
    } else {
      print('Источник: ${Uri.parse(referrer).host}');
    }

    // Анализ UTM меток
    final utmSource = UrlParams.getQueryParameter('utm_source');
    final utmMedium = UrlParams.getQueryParameter('utm_medium');
    final utmCampaign = UrlParams.getQueryParameter('utm_campaign');

    if (utmSource != null) {
      print('UTM Source: $utmSource');
      print('UTM Medium: ${utmMedium ?? 'не указан'}');
      print('UTM Campaign: ${utmCampaign ?? 'не указан'}');
    }

    print('=====================================');
  }
}
