import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/snapshot.dart';
import 'package:nsg_data/v2/controller/nsg_controller_status.dart';

class NsgControllerSnapshot<T extends NsgDataItem> implements Snapshot {
  final Iterable<T> items;
  final int? totalCount;
  final NsgControllerStatus status;
  final Object? error;

  final NsgDataRequestParams requestParams;
  final Iterable<String> loadReference;

  final Iterable<NsgValidateResult> validateResults;

  const NsgControllerSnapshot({
    required this.items,
    required this.totalCount,
    required this.status,
    required this.error,
    required this.requestParams,
    required this.loadReference,
    required this.validateResults,
  });

  factory NsgControllerSnapshot.empty() {
    return NsgControllerSnapshot(
      items: <Never>[],
      totalCount: null,
      status: NsgControllerStatus.idle,
      error: null,
      requestParams: NsgDataRequestParams(),
      loadReference: [],
      validateResults: <NsgValidateResult>[],
    );
  }

  @override
  NsgControllerSnapshot<T> copyWith({
    Iterable<T>? items,
    int? totalCount,
    bool keepCount = true,
    Enum? status,
    Object? error,
    bool keepError = false,
    NsgDataRequestParams? requestParams,
    Iterable<String>? loadReference,
    Iterable<NsgValidateResult>? validateResults,
  }) {
    return NsgControllerSnapshot(
      items: items ?? this.items,
      totalCount: keepCount ? (totalCount ?? this.totalCount) : totalCount,
      status: (status as NsgControllerStatus?) ?? this.status,
      error: keepError ? (error ?? this.error) : error,
      requestParams: requestParams ?? this.requestParams,
      loadReference: loadReference ?? this.loadReference,
      validateResults: validateResults ?? this.validateResults,
    );
  }
}
