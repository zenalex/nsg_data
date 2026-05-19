import 'package:nsg_data/nsg_data_requestParams.dart';

class NsgCachedRequestParams {
  final NsgDataRequestParams params;

  NsgCachedRequestParams({required this.params});

  @override
  String toString() {
    // Исключает те поля, которые не влияют на результат запроса (фактически мы получаем те же объекты, в том же количестве)
    final newParams = params.clone()
      ..top = 0
      ..count = 0
      ..requestId = null
      ..transactionId = null
      ..referenceList = null
      ..sorting = null
      ..neededFields = null;

    return newParams.toJson().toString();
  }
}
