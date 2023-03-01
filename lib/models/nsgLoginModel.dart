// ignore_for_file: file_names

import 'package:nsg_data/authorize/nsgPhoneLoginPage.dart';

class NsgLoginModel {
  Map<String, dynamic> toJson() => {};
}

class NsgLoginResponse {
  String token = '';
  bool isError = false;
  String errorMessage = '';
  bool isAnonymous = true;
  int errorCode = 0;
  double secondsRemaining = 0;

  NsgLoginResponse({this.token = '', this.isError = false, this.errorMessage = '', this.errorCode = 0, this.isAnonymous = true});

  NsgLoginResponse.fromJson(Map<String, dynamic>? json) : super() {
    if (json != null) {
      token = json['token'].toString();
      isError = (json['isError'] ?? false) as bool;
      errorMessage = (json['errorMessage'] ?? '').toString();
      errorCode = (json['errorCode'] ?? 0) as int;
      isAnonymous = (json['isAnonymous'] ?? false) as bool;
      secondsRemaining = (json['secondsRemaining'] ?? 0.0) as double;
    }
  }
}

class NsgPhoneLoginModel extends NsgLoginModel {
  String? phoneNumber;
  String? securityCode;
  String? newPassword;
  NsgLoginType? loginType;
  bool register = false;
  @override
  Map<String, dynamic> toJson() {
    String loginTypeString = '';
    if (loginType == NsgLoginType.email) loginTypeString = 'email';
    if (loginType == NsgLoginType.phone) loginTypeString = 'phone';
    return {'phoneNumber': phoneNumber, 'securityCode': securityCode, 'loginType': loginTypeString, 'register': register, 'newPassword': newPassword};
  }
}
