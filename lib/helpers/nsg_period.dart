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
  DateTime beginDate = Jiffy.parseFromDateTime(DateTime.now()).startOf(Unit.month).dateTime;

  ///Дата окончания периода
  DateTime endDate = Jiffy.parseFromDateTime(DateTime.now()).endOf(Unit.month).dateTime;

  ///Текстовое представление периода. В случае учета веремен, время в отображении не указыватеся
  String dateTextWithoutTime(String locale) => getDateText(false, locale);

  ///Текстовое представление периода. В случае учета веремен, время будет отображено в периоде
  String dateTextWithTime(String locale) => getDateText(true, locale);

  ///Тип периода (определяится автоматически по заданным началу и концу периода)
  NsgPeriodType get type => _detectPeriodType();

  ///Выбрать следующий период
  ///Например, если период месяц - будет выбран следующий месяц
  void plus() {
    switch (type) {
      case NsgPeriodType.year:
        setToYear(Jiffy.parseFromDateTime(beginDate).add(years: 1).dateTime);
        break;
      case NsgPeriodType.quarter:
        setToQuarter(Jiffy.parseFromDateTime(beginDate).add(months: 3).dateTime);
        break;
      case NsgPeriodType.month:
        setToMonth(Jiffy.parseFromDateTime(beginDate).add(months: 1).dateTime);
        break;
      case NsgPeriodType.week:
        setToWeek(Jiffy.parseFromDateTime(beginDate).add(days: 7).dateTime);
        break;
      case NsgPeriodType.day:
        setToDay(Jiffy.parseFromDateTime(beginDate).add(days: 1).dateTime);
        break;
      case NsgPeriodType.period:
        beginDate = Jiffy.parseFromDateTime(beginDate).add(days: 1).dateTime;
        endDate = Jiffy.parseFromDateTime(beginDate).add(days: 1).dateTime;
        break;
      case NsgPeriodType.periodWidthTime:
        beginDate = Jiffy.parseFromDateTime(beginDate).add(days: 1).dateTime;
        endDate = Jiffy.parseFromDateTime(beginDate).add(days: 1).dateTime;
        break;

      default:
      //print('не задан период');
    }
  }

  ///Выбрать предыдущий период
  ///Например, если период месяц - будет выбран предыдущий месяц
  void minus() {
    switch (type) {
      case NsgPeriodType.year:
        setToYear(Jiffy.parseFromDateTime(beginDate).subtract(years: 1).dateTime);
        break;
      case NsgPeriodType.quarter:
        setToQuarter(Jiffy.parseFromDateTime(beginDate).subtract(months: 3).dateTime);
        break;
      case NsgPeriodType.month:
        setToMonth(Jiffy.parseFromDateTime(beginDate).subtract(months: 1).dateTime);
        break;
      case NsgPeriodType.week:
        setToWeek(Jiffy.parseFromDateTime(beginDate).subtract(days: 7).dateTime);
        break;
      case NsgPeriodType.day:
        setToDay(Jiffy.parseFromDateTime(beginDate).subtract(days: 1).dateTime);
        break;
      case NsgPeriodType.period:
        beginDate = Jiffy.parseFromDateTime(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy.parseFromDateTime(beginDate).subtract(days: 1).dateTime;
        break;
      case NsgPeriodType.periodWidthTime:
        beginDate = Jiffy.parseFromDateTime(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy.parseFromDateTime(beginDate).subtract(days: 1).dateTime;
        break;

      default:
      //print("добавление - ошибка");
    }
  }

  ///Задать текстовое представление периода
  ///Возможно, надо заменить переменные на геттеры
  String getDateText(bool? withTime, String locale) {
    switch (type) {
      case NsgPeriodType.year:
        return NsgDateFormat.dateFormat(beginDate, format: 'yyyy г.', locale: locale);
      case NsgPeriodType.quarter:
        //TODO: добавить локализацию
        return NsgDateFormat.dateFormat(beginDate, format: getQuarter(beginDate).toString() + ' квартал yyyy г.', locale: locale);
      case NsgPeriodType.month:
        return NsgDateFormat.dateFormat(beginDate, format: 'MMM yyyy г.', locale: locale);
      case NsgPeriodType.week:
        return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ', locale: locale) +
            NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy', locale: locale);
      case NsgPeriodType.day:
        return NsgDateFormat.dateFormat(beginDate, format: 'd MMM yyyy г.', locale: locale);
      case NsgPeriodType.period:
        return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ', locale: locale) +
            NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy', locale: locale);
      case NsgPeriodType.periodWidthTime:
        if (withTime != null && withTime) {
          return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy (HH:mm) - ', locale: locale) +
              NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy (HH:mm)', locale: locale);
        } else {
          return NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ', locale: locale) +
              NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy', locale: locale);
        }

      //print("добавление - ошибка");
    }
  }

  ///Установить тип периода год
  ///Будет установлен интервал с первого до последнего дня года. Год будет взят из переденной даты
  void setToYear(DateTime date) {
    beginDate = Jiffy.parseFromDateTime(date).startOf(Unit.year).dateTime;
    endDate = Jiffy.parseFromDateTime(beginDate).endOf(Unit.year).dateTime;
  }

  ///Установить тип периода квартал
  ///Будет установлен интервал с первого до последнего дня квартала. Квартал будет взят из переденной даты
  void setToQuarter(DateTime date) {
    beginDate = Jiffy.parseFromDateTime(DateTime(date.year)).add(months: (getQuarter(date) - 1) * 3).dateTime;
    endDate = Jiffy.parseFromDateTime(beginDate).add(months: 3).endOf(Unit.month).dateTime;
  }

  ///Установить тип периода месяц
  ///Будет установлен интервал с первого до последнего дня месяца. Месяц будет взят из переденной даты
  void setToMonth(DateTime date) {
    beginDate = Jiffy.parseFromDateTime(date).startOf(Unit.month).dateTime;
    endDate = Jiffy.parseFromDateTime(beginDate).endOf(Unit.month).dateTime;
  }

  ///Установить тип периода неделя
  ///Будет установлен интервал с первого до последнего дня недели. Неделя будет взят из переденной даты
  void setToWeek(DateTime date) {
    beginDate = Jiffy.parseFromDateTime(date).startOf(Unit.week).dateTime;
    endDate = Jiffy.parseFromDateTime(beginDate).endOf(Unit.week).dateTime;
  }

  ///Установить тип периода год
  ///Будет установлен интервал с начала по конец суток, взятых из переденной даты
  void setToDay(DateTime date) {
    beginDate = Jiffy.parseFromDateTime(date).startOf(Unit.day).dateTime;
    endDate = Jiffy.parseFromDateTime(beginDate).endOf(Unit.day).dateTime;
  }

  ///Установить произвольный период
  ///Период будет задан от начала дня первой даты до конца дня последней
  void setToPeriod(NsgPeriod p) {
    beginDate = Jiffy.parseFromDateTime(p.beginDate).startOf(Unit.day).dateTime;
    endDate = Jiffy.parseFromDateTime(p.endDate).endOf(Unit.day).dateTime;
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
    if (Jiffy.parseFromDateTime(beginDate).isSame(Jiffy.parseFromDateTime(beginDate).startOf(Unit.year)) &&
        Jiffy.parseFromDateTime(endDate).isSame(Jiffy.parseFromDateTime(beginDate).endOf(Unit.year))) {
      return NsgPeriodType.year;
    }
    var qb = Jiffy.parseFromDateTime(DateTime(beginDate.year)).add(months: (getQuarter(beginDate) - 1) * 3);
    var qe = qb.add(months: 3).endOf(Unit.month);
    if (Jiffy.parseFromDateTime(beginDate).isSame(qb) && Jiffy.parseFromDateTime(endDate).isSame(qe)) return NsgPeriodType.quarter;
    //Проверка на месяц
    if (Jiffy.parseFromDateTime(beginDate).isSame(Jiffy.parseFromDateTime(beginDate).startOf(Unit.month)) &&
        Jiffy.parseFromDateTime(endDate).isSame(Jiffy.parseFromDateTime(beginDate).endOf(Unit.month))) {
      return NsgPeriodType.month;
    }
    //Проверка на неделю
    if (Jiffy.parseFromDateTime(beginDate).isSame(Jiffy.parseFromDateTime(beginDate).startOf(Unit.week)) &&
        Jiffy.parseFromDateTime(endDate).isSame(Jiffy.parseFromDateTime(beginDate).endOf(Unit.week))) {
      return NsgPeriodType.week;
    }
    //Проверка на день
    if (Jiffy.parseFromDateTime(beginDate).isSame(Jiffy.parseFromDateTime(beginDate).startOf(Unit.day)) &&
        Jiffy.parseFromDateTime(endDate).isSame(Jiffy.parseFromDateTime(beginDate).endOf(Unit.day))) {
      return NsgPeriodType.day;
    }
    if (Jiffy.parseFromDateTime(beginDate).isSame(Jiffy.parseFromDateTime(beginDate).startOf(Unit.day)) &&
        Jiffy.parseFromDateTime(endDate).isSame(Jiffy.parseFromDateTime(endDate).startOf(Unit.day))) {
      return NsgPeriodType.period;
    }
    return NsgPeriodType.periodWidthTime;
  }

  /// Обнуление даты до начала дня
  static DateTime beginOfDay(DateTime date) {
    return Jiffy.parseFromDateTime(date).startOf(Unit.day).dateTime;
  }

  /// Обнуление даты до начала дня
  static DateTime endOfDay(DateTime date) {
    return Jiffy.parseFromDateTime(date).endOf(Unit.day).dateTime;
  }
}
