import 'package:jiffy/jiffy.dart';
import 'package:nsg_data/helpers/nsg_data_format.dart';
import 'package:nsg_data/nsg_data.dart';

class NsgPeriodType {
  final int type;
  const NsgPeriodType(this.type);
  static const NsgPeriodType year = NsgPeriodType(1);
  static const NsgPeriodType quarter = NsgPeriodType(2);
  static const NsgPeriodType month = NsgPeriodType(3);
  static const NsgPeriodType week = NsgPeriodType(4);
  static const NsgPeriodType day = NsgPeriodType(5);
  static const NsgPeriodType period = NsgPeriodType(6);
  static const NsgPeriodType periodWidthTime = NsgPeriodType(7);

  @override
  bool operator ==(Object other) => other is NsgPeriodType && equal(other);
  bool equal(NsgPeriodType other) {
    return other.type == type;
  }

  @override
  int get hashCode {
    return type;
  }
}

class NsgPeriod {
  DateTime beginDate = Jiffy(DateTime.now()).startOf(Units.MONTH).dateTime;
  DateTime endDate = Jiffy(DateTime.now()).endOf(Units.MONTH).dateTime;
  String dateText = '';
  String dateWidgetText = '';
  NsgPeriodType get type => _detectPeriodType();

  void plus() {
    switch (type.type) {
      case 1:
        setToYear(Jiffy(beginDate).add(years: 1).dateTime);
        break;
      case 2:
        setToQuarter(Jiffy(beginDate).add(months: 3).dateTime);
        break;
      case 3:
        setToMonth(Jiffy(beginDate).add(months: 1).dateTime);
        break;
      case 4:
        setToWeek(Jiffy(beginDate).add(days: 7).dateTime);
        break;
      case 5:
        setToDay(Jiffy(beginDate).add(days: 1).dateTime);
        break;
      case 6:
        beginDate = Jiffy(beginDate).add(days: 1).dateTime;
        endDate = Jiffy(beginDate).add(days: 1).dateTime;
        break;
      case 7:
        beginDate = Jiffy(beginDate).add(days: 1).dateTime;
        endDate = Jiffy(beginDate).add(days: 1).dateTime;
        break;

      default:
        print('не задан период');
    }
  }

  void minus() {
    switch (type.type) {
      case 1:
        setToYear(Jiffy(beginDate).subtract(years: 1).dateTime);
        break;
      case 2:
        setToQuarter(Jiffy(beginDate).subtract(months: 3).dateTime);
        break;
      case 3:
        setToMonth(Jiffy(beginDate).subtract(months: 1).dateTime);
        break;
      case 4:
        setToWeek(Jiffy(beginDate).subtract(days: 7).dateTime);
        break;
      case 5:
        setToDay(Jiffy(beginDate).subtract(days: 1).dateTime);
        break;
      case 6:
        beginDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        break;
      case 7:
        beginDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        break;

      default:
        print("добавление - ошибка");
    }
  }

  void setDateText() {
    switch (type.type) {
      case 1:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: 'yyyy г.');
        break;
      case 2:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: getQuarter(beginDate).toString() + ' квартал yyyy г.');
        break;
      case 3:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: 'MMM yyyy г.');
        break;
      case 4:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy');
        break;
      case 5:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: 'dd MMMM yyyy г.');
        break;
      case 6:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy');
        break;
      case 7:
        dateText = NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy');
        dateWidgetText = NsgDateFormat.dateFormat(beginDate, format: 'dd.MM.yy (HH:mm) - ') + NsgDateFormat.dateFormat(endDate, format: 'dd.MM.yy (HH:mm)');
        break;

      default:
        print("добавление - ошибка");
    }
  }

  void setToYear(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.YEAR).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.YEAR).dateTime;
    setDateText();
  }

  void setToQuarter(DateTime date) {
    beginDate = Jiffy(DateTime(date.year)).add(months: (getQuarter(date) - 1) * 3).dateTime;
    endDate = Jiffy(beginDate).add(months: 3).endOf(Units.MONTH).dateTime;
    setDateText();
  }

  void setToMonth(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.MONTH).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.MONTH).dateTime;
    setDateText();
  }

  void setToWeek(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.WEEK).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.WEEK).dateTime;
    setDateText();
  }

  void setToDay(DateTime date) {
    beginDate = Jiffy(date).startOf(Units.DAY).dateTime;
    endDate = Jiffy(beginDate).endOf(Units.DAY).dateTime;
    setDateText();
  }

  void setToPeriod(NsgPeriod p) {
    beginDate = Jiffy(p.beginDate).startOf(Units.DAY).dateTime;
    endDate = Jiffy(p.endDate).endOf(Units.DAY).dateTime;
    setDateText();
  }

  void setToPeriodWithTime(NsgPeriod p) {
    beginDate = p.beginDate;
    endDate = p.endDate;
    setDateText();
  }

  // DateTime dateZeroTime(DateTime date) {
  //   return DateTime(date.year, date.month, date.day);
  // }

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
}
