import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/authorize/nsg_login_response.dart';

void main() {
  test('jsonDecode of a whole 1800 keeps the code and the delay', () {
    final json =
        jsonDecode(
              '{"errorCode":40300,"isError":true,"secondsBeforeRepeat":1800,"secondsRemaining":1800}',
            )
            as Map<String, dynamic>;

    final response = NsgLoginResponse.fromJson(json);

    expect(response.errorCode, 40300);
    expect(response.secondsBeforeRepeat, 1800);
    expect(response.secondsRemaining, 1800);
    expect(response.isError, isTrue);
  });

  test('fractional seconds and a whole-number error code both parse', () {
    final json =
        jsonDecode(
              '{"errorCode":40300.0,"secondsBeforeRepeat":1799.5,"secondsRemaining":0.0}',
            )
            as Map<String, dynamic>;

    final response = NsgLoginResponse.fromJson(json);

    expect(response.errorCode, 40300);
    expect(response.secondsBeforeRepeat, 1799.5);
    expect(response.secondsRemaining, 0);
  });

  test('missing delay keys stay zero', () {
    final response = NsgLoginResponse.fromJson(
      jsonDecode('{}') as Map<String, dynamic>,
    );

    expect(response.errorCode, 0);
    expect(response.secondsBeforeRepeat, 0);
    expect(response.secondsRemaining, 0);
  });
}
