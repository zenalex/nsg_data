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
      token = json['token'].toString();
      isError = (json['isError'] ?? false) as bool;
      errorMessage = (json['errorMessage'] ?? '').toString();
      errorCode = (json['errorCode'] ?? 0) as int;
      isAnonymous = (json['isAnonymous'] ?? false) as bool;
      secondsRemaining = (json['secondsRemaining'] ?? 0.0) as double;
      secondsBeforeRepeat = (json['secondsBeforeRepeat'] ?? 0.0) as double;
    }
  }
}
