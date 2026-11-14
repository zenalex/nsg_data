class NsgLoginResponse {
  String token = '';
  bool isError = false;
  String errorMessage = '';
  bool isAnonymous = true;
  int errorCode = 0;
  double secondsRemaining = 0;
  double secondsBeforeRepeat = 0;

  NsgLoginResponse({this.token = '', this.isError = false, this.errorMessage = '', this.errorCode = 0, this.isAnonymous = true});

  NsgLoginResponse.fromJson(Map<String, dynamic>? json) : super() {
    if (json != null) {
      final rawToken = json['token'];
      token = rawToken == null ? '' : rawToken.toString();
      isError = (json['isError'] ?? false) as bool;
      errorMessage = (json['errorMessage'] ?? '').toString();
      errorCode = _jsonInt(json['errorCode']);
      isAnonymous = (json['isAnonymous'] ?? false) as bool;
      secondsRemaining = _jsonDouble(json['secondsRemaining']);
      secondsBeforeRepeat = _jsonDouble(json['secondsBeforeRepeat']);
    }
  }
}

/// JSON numbers arrive as int or double. `as int` / `as double` throws on the other.
int _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

double _jsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  return 0;
}
