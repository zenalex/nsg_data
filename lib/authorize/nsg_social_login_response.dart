class NsgSocialLoginResponse {
  String state;
  String code;
  String deviceId;
  String? email;
  String? firstName;
  String? lastName;
  NsgSocialLoginResponse({this.state = '', this.code = '', this.deviceId = '', this.email, this.firstName, this.lastName});

  bool get isEmpty {
    if (state == '' || code == '') return true;
    return false;
  }

  void fromJson(Map<String, dynamic>? json) {
    if (json != null) {
      state = json['state'] ?? '';
      code = json['code'] ?? '';
      deviceId = json['device_id'] ?? '';
      email = json['email'];
      firstName = json['firstName'];
      lastName = json['lastName'];
    }
  }
}
