import 'dart:convert';

import 'package:nsg_data/authorize/nsg_login_model.dart';

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
      final rawPayload = json['payload'];
      if (rawPayload is Map<String, dynamic>) {
        payload = rawPayload;
      } else if (rawPayload is String && rawPayload.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawPayload);
          payload = decoded is Map<String, dynamic> ? decoded : null;
        } catch (_) {
          payload = null;
        }
      }
    }
  }

  Map<String, dynamic> toJson() => toLoginModel().toJson();

  NsgLoginModel toLoginModel() => NsgLoginModel()
    ..code = code
    ..deviceId = deviceId
    ..payload = payload
    ..state = state
    ..loginTypeString = loginType;
}
