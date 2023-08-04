import 'dart:async';

import 'package:nsg_data/nsg_data.dart';

///Класс, задающий параметры фильтрации для контроллера данных
///isAllowed - разрешена ли фильтрация в принципе (показывать ли значек фильтра)
///isOpen - открыт ли фильтр на экране и, соотвтественно, применяется ли фильтр к данным
///searchString - строка поиска
///isPeriodAllowed - разрешена ли фильтрация по периоду. Показывать ли пользоваателю соответсмтвующий элемент управления
///periodFieldName - на какое поле элементов данных будет накладываться фильтр
///
///
//После изменения параметров фильтирации необходимо вызват обновление данных у контроллера - refreshData()

class NsgControllerFilter {
  ///Контроллер, на который будет накладываться фильтр
  NsgBaseController? controller;

  ///Разрешить использование фильтра для данного контроллера
  bool isAllowed = true;

  ///Разрешить фильтрацию по периоду
  bool isPeriodAllowed = false;

  ///Поле объекта, на которое накладывается фильтр по периоду
  String periodFieldName = '';

  ///Открыт ли фильтр на экране
  bool isOpen = false;

  ///Открыт ли фильтр по строке на экране
  bool? isSearchStringFilterOpen;

  ///Строка поиска. Должна применяться через метод updateController для задержки срабатывания,
  ///что дает пользователю ввести строку поиска не вызвав серию обновлений контроллера до окончания ввода
  String searchString = '';

  ///Период фильтрации (применяыется если isPeriodAllowed == true)
  NsgPeriod nsgPeriod = NsgPeriod();

  ///Текущий тип периода (по умолчанию - месяц)
  NsgPeriodType periodSelected = NsgPeriodType.month;

  ///Позволить пользователю вводить не только дату, но и время
  bool periodTimeEnabled = false;

  ///Задержка на обновление контроллера при изменении текста пользователем
  Duration updateDelay = const Duration(milliseconds: 1000);

  ///Таймер задержки обновления контроллера
  Timer? _updateTimer;

  ///Обновить данные в контроллере c задержкой по времени
  ///Каждый новый вызов этого метода отменяет предыдущий и сбрасывает время ожидание на ноль
  void refreshControllerWithDelay({NsgDataRequestParams? filter}) {
    if (_updateTimer != null) {
      _updateTimer!.cancel();
    }
    _updateTimer = Timer(updateDelay, () => _updateTick(filter: filter));
    //_updateTimer.isActive = true;
  }

  void _updateTick({NsgDataRequestParams? filter}) {
    controller?.refreshData(filter: filter);
  }
}
