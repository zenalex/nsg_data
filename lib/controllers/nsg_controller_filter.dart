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
  bool isAllowed = true;
  bool isPeriodAllowed = false;
  String periodFieldName = '';
  bool isOpen = false;
  String searchString = '';
  NsgPeriod nsgPeriod = NsgPeriod();
  int periodSelected = 3;
  bool periodTimeEnabled = false;
}
