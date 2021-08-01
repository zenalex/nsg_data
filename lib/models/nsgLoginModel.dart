class NsgLoginModel {
  Map<String, dynamic> toJson() => {};
}

class NsgLoginResponse {
  String token = '';
  bool isError = false;
  String errorMessage = '';
  bool isAnonymous = true;
  int errorCode = 0;

  NsgLoginResponse.fromJson(Map<String, dynamic>? json) : super() {
    if (json != null) {
      token = json['token'].toString();
      isError = json['isError'] as bool;
      errorMessage = json['errorMessage'].toString();
      errorCode = json['errorCode'] as int;
      isAnonymous = json['isAnonymous'] as bool;
    }
  }
}

class NsgPhoneLoginModel extends NsgLoginModel {
  String? phoneNumber;
  String? securityCode;
  @override
  Map<String, dynamic> toJson() {
    return {'phoneNumber': phoneNumber, 'securityCode': securityCode};
  }
}
