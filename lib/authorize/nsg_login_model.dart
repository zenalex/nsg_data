// ignore_for_file: file_names

class NsgLoginModel {
  String? phoneNumber;
  String? securityCode;
  String? newPassword;
  NsgLoginType? loginType;
  bool register = false;
  String firebaseToken = '';
  String? code;
  String? state;
  String? deviceId;
  String? loginTypeString;
  Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() {
    if (loginTypeString == null) {
      if (loginType == NsgLoginType.email) {
        loginTypeString = 'email';
      } else if (loginType == NsgLoginType.phone) {
        loginTypeString = 'phone';
      } else {
        loginTypeString = '';
      }
    }

    return {
      'phoneNumber': phoneNumber,
      'securityCode': securityCode,
      'loginType': loginTypeString,
      'register': register,
      'newPassword': newPassword,
      'code': code,
      'state': state,
      'deviceId': deviceId,
      'payload': payload,
    };
  }
}

///Тип выбранной пользователем авторизации
enum NsgLoginType { phone, email }
