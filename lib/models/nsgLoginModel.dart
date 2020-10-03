class NsgLoginModel {
  Map<String, dynamic> toJson() => {};
}

class NsgLoginResponse {
  String token;
  bool isError;
  String errorMessage;
  bool isAnonymous;
  int errorCode;

  NsgLoginResponse.fromJson(Map<String, dynamic> json)
      : token = json['Token'].toString(),
        isError = json['IsError'] as bool,
        errorMessage = json['ErrorMessage'].toString(),
        errorCode = json['ErrorCode'] as int,
        isAnonymous = json['IsAnonymous'] as bool;
}

class NsgPhoneLoginModel extends NsgLoginModel {
  String phoneNumber;
  String securityCode;
  @override
  Map<String, dynamic> toJson() {
    return {'PhoneNumber': phoneNumber, 'SecurityCode': securityCode};
  }
}
