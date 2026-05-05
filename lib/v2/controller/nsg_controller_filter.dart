import 'package:nsg_data/nsg_data.dart';
import 'package:nsg_data/v2/abstract/snapshot.dart';

class NsgControllerFilterV2 implements Snapshot {
  ///Строка поиска. Должна применяться через метод updateController для задержки срабатывания,
  ///что дает пользователю ввести строку поиска не вызвав серию обновлений контроллера до окончания ввода
  final String searchString;

  ///Период фильтрации (применяыется если isPeriodAllowed == true)
  final NsgTypedPeriod nsgPeriod;

  const NsgControllerFilterV2({required this.searchString, required this.nsgPeriod});

  factory NsgControllerFilterV2.empty() {
    return NsgControllerFilterV2(searchString: '', nsgPeriod: NsgTypedPeriod.day(DateTime.now()));
  }

  @override
  NsgControllerFilterV2 copyWith({String? searchString, NsgTypedPeriod? nsgPeriod}) {
    return NsgControllerFilterV2(searchString: searchString ?? this.searchString, nsgPeriod: nsgPeriod ?? this.nsgPeriod);
  }
}
