// ignore_for_file: file_names

class NsgLoginModel {
  String? phoneNumber;
  String? securityCode;
  String? newPassword;
  NsgLoginType? loginType;
  bool register = false;
  String firebaseToken = '';

  Map<String, dynamic> toJson() {
    String loginTypeString = '';
    if (loginType == NsgLoginType.email) loginTypeString = 'email';
    if (loginType == NsgLoginType.phone) loginTypeString = 'phone';
    return {
      'phoneNumber': phoneNumber,
      'securityCode': securityCode,
      'loginType': loginTypeString,
      'register': register,
      'newPassword': newPassword,
    };
  }
}

///Тип выбранной пользователем авторизации
enum NsgLoginType { phone, email }
