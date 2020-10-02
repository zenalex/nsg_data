class NsgLoginModel {
  Map<String, dynamic> toJson() => {};
}

class NsgLoginResponse {
  String token;
  bool isError;
  String errorMessage;
  bool isAnonymous;

  NsgLoginResponse.fromJson(Map<String, dynamic> json)
      : token = json['Token'].toString(),
        isError = json['IsError'] as bool,
        errorMessage = json['ErrorMessage'].toString(),
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
