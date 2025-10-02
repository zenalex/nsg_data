// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setUrlParams(Map<String, String> params, {bool replace = true, String? path}) {
  final uri = Uri(path: path ?? html.window.location.pathname, queryParameters: params.isEmpty ? null : params);
  final url = uri.toString();
  if (replace) {
    html.window.history.replaceState(null, '', url);
  } else {
    html.window.history.pushState(null, '', url);
  }
}


