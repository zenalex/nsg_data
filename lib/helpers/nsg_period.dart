import 'package:jiffy/jiffy.dart';
import 'package:nsg_data/helpers/nsg_data_format.dart';
import 'package:nsg_data/nsg_data.dart';

enum NsgPeriodType {
  year(1),
  quarter(2),
  month(3),
  week(4),
  day(5),
  period(6),
  periodWidthTime(7);

  final int periodType;
  const NsgPeriodType(this.periodType);
}

///Класс для задания фиолтра по периоду. Используется, например, в фильтре контроллера данных
class NsgPeriod {
  ///дата начала периода
  DateTime beginDate = Jiffy(DateTime.now()).startOf(Units.MONTH).dateTime;

  ///Дата окончания периода
  DateTime endDate = Jiffy(DateTime.now()).endOf(Units.MONTH).dateTime;

  ///Текстовое представление периода. В случае учета веремен, время в отображении не указыватеся
  String get dateTextWithoutTime => getDateText(false);

  ///Текстовое представление периода. В случае учета веремен, время будет отображено в периоде
  String get dateTextWithTime => getDateText(true);

  ///Тип периода (определяится автоматически по заданным началу и концу периода)
  NsgPeriodType get type => _detectPeriodType();

  ///Выбрать следующий период
  ///Например, если период месяц - будет выбран следующий месяц
  void plus() {
    switch (type) {
      case NsgPeriodType.year:
        setToYear(Jiffy(beginDate).add(years: 1).dateTime);
        break;
      case NsgPeriodType.quarter:
        setToQuarter(Jiffy(beginDate).add(months: 3).dateTime);
        break;
      case NsgPeriodType.month:
        setToMonth(Jiffy(beginDate).add(months: 1).dateTime);
        break;
      case NsgPeriodType.week:
        setToWeek(Jiffy(beginDate).add(days: 7).dateTime);
        break;
      case NsgPeriodType.day:
        setToDay(Jiffy(beginDate).add(days: 1).dateTime);
        break;
      case NsgPeriodType.period:
        beginDate = Jiffy(beginDate).add(days: 1).dateTime;
        endDate = Jiffy(beginDate).add(days: 1).dateTime;
        break;
      case NsgPeriodType.periodWidthTime:
        beginDate = Jiffy(beginDate).add(days: 1).dateTime;
        endDate = Jiffy(beginDate).add(days: 1).dateTime;
        break;

      default:
        print('не задан период');
    }
  }

  ///Выбрать предыдущий период
  ///Например, если период месяц - будет выбран предыдущий месяц
  void minus() {
    switch (type) {
      case NsgPeriodType.year:
        setToYear(Jiffy(beginDate).subtract(years: 1).dateTime);
        break;
      case NsgPeriodType.quarter:
        setToQuarter(Jiffy(beginDate).subtract(months: 3).dateTime);
        break;
      case NsgPeriodType.month:
        setToMonth(Jiffy(beginDate).subtract(months: 1).dateTime);
        break;
      case NsgPeriodType.week:
        setToWeek(Jiffy(beginDate).subtract(days: 7).dateTime);
        break;
      case NsgPeriodType.day:
        setToDay(Jiffy(beginDate).subtract(days: 1).dateTime);
        break;
      case NsgPeriodType.period:
        beginDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        break;
      case NsgPeriodType.periodWidthTime:
        beginDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        break;

      default:
        print("добавление - ошибка");
    }
  }

  ///Задать текстовое представление периода
  ///Возможно, надо заменить переменные на геттеры
  String getDateText(bool? withTime) {
    switch (type) {
      case NsgPeriodType.year:
        return NsgDateFormat.dateFormat(beginDate, format: 'yyyy г.');
      case NsgPeriodType.quarter:
        return NsgDateFormat.dateFormat(beginDate, format: getQuarter(beginDate).toString() + ' квартал yyyy г.');
      case NsgPeriodType.month:
        return NsgDateFormat.dateFormat(beginDate, format: 'MMM yyyy г.');
      case NsgPeriodType.week:
        return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy');
      case NsgPeriodType.day:
        return NsgDateFormat.dateFormat(beginDate, format: 'dd MMMM yyyy г.');
      case NsgPeriodType.period:
        return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy');
      case NsgPeriodType.periodWidthTime:
        if (withTime != null && withTime) {
          return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy (HH:mm) - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy (HH:mm)');
        } else {
          return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy');
        }

      default:
        print("добавление - ошибка");
    }
    return '';
  }

  ///Установить тип периода год
  ///Будет установлен интервал с первого до последнего дня года. Год будет взят из переденной даты
  void setToYear(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.YEAR).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.YEAR).dateTime;
  }

  ///Установить тип периода квартал
  ///Будет установлен интервал с первого до последнего дня квартала. Квартал будет взят из переденной даты
  void setToQuarter(DateTime date) {
    beginDate = Jiffy(DateTime(date.year)).add(months: (getQuarter(date) - 1) * 3).dateTime;
    endDate = Jiffy(beginDate).add(months: 3).endOf(Units.MONTH).dateTime;
  }

  ///Установить тип периода месяц
  ///Будет установлен интервал с первого до последнего дня месяца. Месяц будет взят из переденной даты
  void setToMonth(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.MONTH).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.MONTH).dateTime;
  }

  ///Установить тип периода неделя
  ///Будет установлен интервал с первого до последнего дня недели. Неделя будет взят из переденной даты
  void setToWeek(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.WEEK).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.WEEK).dateTime;
  }

  ///Установить тип периода год
  ///Будет установлен интервал с начала по конец суток, взятых из переденной даты
  void setToDay(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.DAY).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.DAY).dateTime;
  }

  ///Установить произвольный период
  ///Период будет задан от начала дня первой даты до конца дня последней
  void setToPeriod(NsgPeriod p) {
    beginDate = Jiffy(p.beginDate).startOf(Units.DAY).dateTime;
    endDate = Jiffy(p.endDate).endOf(Units.DAY).dateTime;
  }

  ///Установить произвольный период с учетов времени
  void setToPeriodWithTime(NsgPeriod p) {
    beginDate = p.beginDate;
    endDate = p.endDate;
  }

  ///Определить номер квартала по дате
  int getQuarter(DateTime date) {
    int kvartal = (date.month / 3).ceil();
    return kvartal;
  }

  ///Определить тип периода по начальной и конечной дате
  NsgPeriodType _detectPeriodType() {
    //Проверка на год
    if (Jiffy(beginDate).isSame(Jiffy(beginDate).startOf(Units.YEAR)) && Jiffy(endDate).isSame(Jiffy(beginDate).endOf(Units.YEAR))) return NsgPeriodType.year;
    var qb = Jiffy(DateTime(beginDate.year)).add(months: (getQuarter(beginDate) - 1) * 3);
    var qe = qb.add(months: 3).endOf(Units.MONTH);
    if (Jiffy(beginDate).isSame(qb) && Jiffy(endDate).isSame(qe)) return NsgPeriodType.quarter;
    //Проверка на месяц
    if (Jiffy(beginDate).isSame(Jiffy(beginDate).startOf(Units.MONTH)) && Jiffy(endDate).isSame(Jiffy(beginDate).endOf(Units.MONTH)))
      return NsgPeriodType.month;
    //Проверка на неделю
    if (Jiffy(beginDate).isSame(Jiffy(beginDate).startOf(Units.WEEK)) && Jiffy(endDate).isSame(Jiffy(beginDate).endOf(Units.WEEK))) return NsgPeriodType.week;
    //Проверка на день
    if (Jiffy(beginDate).isSame(Jiffy(beginDate).startOf(Units.DAY)) && Jiffy(endDate).isSame(Jiffy(beginDate).endOf(Units.DAY))) return NsgPeriodType.day;
    if (Jiffy(beginDate).isSame(Jiffy(beginDate).startOf(Units.DAY)) && Jiffy(endDate).isSame(Jiffy(endDate).endOf(Units.DAY))) return NsgPeriodType.period;
    return NsgPeriodType.periodWidthTime;
  }

  /// Обнуление даты до начала дня
  static DateTime beginOfDay(DateTime date) {
    return Jiffy(date).startOf(Units.DAY).dateTime;
  }
}
