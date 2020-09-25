class NsgLoginModel {
  Map<String, dynamic> toJson() => {};
}

class NsgLoginResponse {
  String token;
  bool isError;
  String errorMessage;
  bool isAnonymous;

  NsgLoginResponse.fromJson(Map<String, dynamic> json)
      : token = json['Token'],
        isError = json['IsError'],
        errorMessage = json['ErrorMessage'],
        isAnonymous = json['IsAnonymous'];
}

class NsgPhoneLoginModel extends NsgLoginModel {
  String phoneNumber;
  String securityCode;
}
