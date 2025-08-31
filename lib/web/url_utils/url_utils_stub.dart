/// Заглушка для не-веб платформ
class UrlUtils {
  static String getCurrentUrl() => '';
  static String getCurrentOrigin() => '';
  static String getCurrentHostname() => '';
  static String getCurrentPathname() => '';
  static String getCurrentSearch() => '';
  static String getCurrentHash() => '';
  static String getReferrer() => '';
  static bool isSecureUrl() => false;
  static String getBaseUrl() => '';
  static String getPort() => '';
  static String getProtocol() => '';
  static void printUrlInfo() {}
}

class UrlParams {
  static Map<String, String> getQueryParameters() => {};
  static String? getQueryParameter(String key) => null;
  static bool hasQueryParameter(String key) => false;
  static String getQueryParametersString() => '';
}

class UrlExamples {
  static void exampleUsage() {}
  static void logUserJourney() {}
}
