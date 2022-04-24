import 'package:jiffy/jiffy.dart';
import 'package:nsg_data/helpers/nsg_data_format.dart';

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
  DateTime endDate = DateTime.now();
  DateTime beginDate = Jiffy(DateTime.now()).subtract(months: 3).dateTime;
  String dateText = '';
  String dateWidgetText = '';
  NsgPeriodType type = NsgPeriodType.year;

  void plus() {
    switch (type.type) {
      case 1:
        beginDate = Jiffy(beginDate).add(years: 1).dateTime;
        endDate = Jiffy(beginDate).add(years: 1).dateTime;
        break;
      case 2:
        beginDate = Jiffy(beginDate).add(months: 3).dateTime;
        endDate = Jiffy(beginDate).add(months: 3).dateTime;
        break;
      case 3:
        beginDate = Jiffy(beginDate).add(months: 1).dateTime;
        endDate = Jiffy(beginDate).add(months: 1).dateTime;
        break;
      case 4:
        beginDate = Jiffy(beginDate).add(days: 7).dateTime;
        endDate = Jiffy(beginDate).add(days: 7).dateTime;
        break;
      case 5:
        beginDate = Jiffy(beginDate).add(days: 1).dateTime;
        endDate = Jiffy(beginDate).add(days: 1).dateTime;
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
        beginDate = Jiffy(beginDate).subtract(years: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(years: 1).dateTime;
        break;
      case 2:
        beginDate = Jiffy(beginDate).subtract(months: 3).dateTime;
        endDate = Jiffy(beginDate).subtract(months: 3).dateTime;
        break;
      case 3:
        beginDate = Jiffy(beginDate).subtract(months: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(months: 1).dateTime;
        break;
      case 4:
        beginDate = Jiffy(beginDate).subtract(days: 7).dateTime;
        endDate = Jiffy(beginDate).subtract(days: 7).dateTime;
        break;
      case 5:
        beginDate = Jiffy(beginDate).subtract(days: 1).dateTime;
        endDate = Jiffy(beginDate).subtract(days: 1).dateTime;
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
        dateText =
            dateWidgetText = NsgDateFormat.dateFormat(beginDate, 'yyyy г.');
        break;
      case 2:
        dateText = dateWidgetText = NsgDateFormat.dateFormat(
            beginDate, getQuarter(beginDate).toString() + ' квартал yyyy г.');
        break;
      case 3:
        dateText =
            dateWidgetText = NsgDateFormat.dateFormat(beginDate, 'MMM yyyy г.');
        break;
      case 4:
        dateText = dateWidgetText =
            NsgDateFormat.dateFormat(beginDate, 'dd.MM.yy - ') +
                NsgDateFormat.dateFormat(endDate, 'dd.MM.yy');
        break;
      case 5:
        dateText = dateWidgetText =
            NsgDateFormat.dateFormat(beginDate, 'dd MMMM yyyy г.');
        break;
      case 6:
        dateText = dateWidgetText =
            NsgDateFormat.dateFormat(beginDate, 'dd.MM.yy - ') +
                NsgDateFormat.dateFormat(endDate, 'dd.MM.yy');
        break;
      case 7:
        dateText = NsgDateFormat.dateFormat(beginDate, 'dd.MM.yy - ') +
            NsgDateFormat.dateFormat(endDate, 'dd.MM.yy');
        dateWidgetText =
            NsgDateFormat.dateFormat(beginDate, 'dd.MM.yy (HH:mm) - ') +
                NsgDateFormat.dateFormat(endDate, 'dd.MM.yy (HH:mm)');
        break;

      default:
        print("добавление - ошибка");
    }
  }

  void setToYear(DateTime date) {
    beginDate = DateTime(date.year);
    endDate = Jiffy(DateTime(date.year)).add(years: 1).dateTime;
    type = NsgPeriodType.year;
    setDateText();
  }

  void setToQuarter(DateTime date) {
    beginDate = Jiffy(DateTime(date.year))
        .add(months: (getQuarter(date) - 1) * 3)
        .dateTime;
    endDate = Jiffy(beginDate)
        .add(months: 3)
        .dateTime
        .subtract(const Duration(microseconds: 1));
    type = NsgPeriodType.quarter;
    setDateText();
  }

  void setToMonth(DateTime date) {
    beginDate = DateTime(date.year, date.month);
    endDate = Jiffy(beginDate)
        .add(months: 1)
        .dateTime
        .subtract(const Duration(microseconds: 1));
    type = NsgPeriodType.month;
    setDateText();
  }

  void setToWeek(DateTime date) {
    beginDate = dateZeroTime(date).subtract(Duration(days: date.weekday - 1));
    endDate = beginDate
        .add(const Duration(days: 7))
        .subtract(const Duration(microseconds: 1));
    type = NsgPeriodType.week;
    setDateText();
  }

  void setToDay(DateTime date) {
    beginDate = dateZeroTime(date);
    endDate = beginDate;
    type = NsgPeriodType.day;
    setDateText();
  }

  void setToPeriod(NsgPeriod date) {
    beginDate = dateZeroTime(date.beginDate);
    endDate = dateZeroTime(date.endDate);
    type = NsgPeriodType.period;
    setDateText();
  }

  void setToPeriodWithTime(NsgPeriod date) {
    beginDate = date.beginDate;
    endDate = date.endDate;
    type = NsgPeriodType.periodWidthTime;
    setDateText();
  }

  DateTime dateZeroTime(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int getQuarter(DateTime date) {
    int kvartal = (date.month / 3).ceil();
    return kvartal;
  }
}
