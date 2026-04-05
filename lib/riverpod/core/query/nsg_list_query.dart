import 'dart:convert';

import 'package:nsg_data/nsg_data.dart';

class NsgListQuery {
  final NsgDataRequestParams requestParams;

  NsgListQuery({NsgDataRequestParams? requestParams})
    : requestParams = requestParams?.clone() ?? NsgDataRequestParams();

  NsgListQuery copyWith({NsgDataRequestParams? requestParams}) {
    return NsgListQuery(requestParams: requestParams ?? this.requestParams);
  }

  String get signature => jsonEncode(requestParams.toJson());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NsgListQuery && other.signature == signature;
  }

  @override
  int get hashCode => signature.hashCode;
}
