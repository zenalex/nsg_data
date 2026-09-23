import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

void main() {
  test('SkipTotalCount is opt-in and serialized only when enabled', () {
    expect(NsgDataRequestParams().toJson(), isNot(contains('SkipTotalCount')));

    final params = NsgDataRequestParams(skipTotalCount: true);
    expect(params.toJson()['SkipTotalCount'], isTrue);
    expect(params.clone().skipTotalCount, isTrue);
  });
}
