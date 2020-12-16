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
      : token = json['token'].toString(),
        isError = json['isError'] as bool,
        errorMessage = json['errorMessage'].toString(),
        errorCode = json['errorCode'] as int,
        isAnonymous = json['isAnonymous'] as bool;
}

class NsgPhoneLoginModel extends NsgLoginModel {
  String phoneNumber;
  String securityCode;
  @override
  Map<String, dynamic> toJson() {
    return {'phoneNumber': phoneNumber, 'securityCode': securityCode};
  }
}
