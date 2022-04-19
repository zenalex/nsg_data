///Класс, задающий параметры фильтрации для контроллера данных
///isAllowed - разрешена ли фильтрация в принципе (показывать ли значек фильтра)
///isOpen - открыт ли фильтр на экране и, соотвтественно, применяется ли фильтр к данным
///searchString - строка поиска
///
//После изменения параметров фильтирации необходимо вызват обновление данных у контроллера - refreshData()
class NsgControllerFilter {
  bool isAllowed = true;
  bool isPeriodAllowed = false;
  bool isOpen = false;
  String searchString = '';
}
