class NsgSocialLoginResponse {
  String state;
  String code;
  String deviceId;
  Map<String, dynamic>? payload;
  NsgSocialLoginResponse({
    this.state = '',
    this.code = '',
    this.deviceId = '',
    this.payload,
  });

  bool get isEmpty {
    if (state == '' || code == '') return true;
    return false;
  }

  void fromJson(Map<String, dynamic>? json) {
    if (json != null) {
      state = json['state'] ?? '';
      code = json['code'] ?? '';
      deviceId = json['device_id'] ?? '';
      payload = json['payload'];
    }
  }
}
