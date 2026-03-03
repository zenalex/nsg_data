class NsgSocialLoginResponse {
  String state;
  String code;
  String deviceId;
  String loginType;
  Map<String, dynamic>? payload;
  NsgSocialLoginResponse({this.state = '', this.code = '', this.deviceId = '', this.loginType = '', this.payload});

  bool get isEmpty {
    if (state == '' || code == '') return true;
    return false;
  }

  void fromJson(Map<String, dynamic>? json) {
    if (json != null) {
      state = json['state'] ?? '';
      code = json['code'] ?? '';
      deviceId = json['device_id'] ?? '';
      loginType = json['loginType'] ?? '';
      payload = json['payload'];
    }
  }

  Map<String, dynamic> toJson() {
    return {'state': state, 'code': code, 'device_id': deviceId, 'payload': payload, 'loginType': loginType};
  }
}
