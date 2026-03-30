import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:nsg_data/nsg_data.dart';

/// Примитивный период
abstract class NsgPeriodNew<T extends Comparable<T>> {
  final T begin;
  final T end;

  /// Основной конструктор периода с валидацией
  NsgPeriodNew(T timeBegin, T timeEnd) : begin = timeBegin, end = timeEnd {
    _validate(timeBegin, timeEnd);
  }

  /// Создание нового периода с изменённым началом
  NsgPeriodNew copyWithBegin(T begin);

  /// Создание нового периода с изменённым концом
  NsgPeriodNew copyWithEnd(T end);

  void _validate(T timeBegin, T timeEnd) {
    if (timeBegin.compareTo(timeEnd) >= 1) {
      throw ArgumentError('Начало периода ($timeBegin) не может быть позже конца ($timeEnd)');
    }
  }

  /// Проверка на пустой период
  bool get isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Проверка, что момент времени находится в периоде
  bool checkIn(T time) => time.compareTo(begin) >= 0 && time.compareTo(end) <= 0;

  /// Удобный вывод для отладки
  @override
  String toString() => '${begin.toString()} - ${end.toString()}';

  /// Сравнение объектов
  @override
  bool operator ==(Object other) => other is NsgPeriodNew<T> && begin.compareTo(other.begin) == 0 && end.compareTo(other.end) == 0;

  @override
  int get hashCode => Object.hash(begin, end);
}

/// Временной период
class NsgTimeOfDayPeriod extends NsgPeriodNew<TimeOfDay> {
  /// Основной конструктор с валидацией
  NsgTimeOfDayPeriod(super.timeBegin, super.timeEnd);

  /// Конструктор из DateTime
  NsgTimeOfDayPeriod.date(DateTime timeBegin, DateTime timeEnd) : this(TimeOfDay.fromDateTime(timeBegin), TimeOfDay.fromDateTime(timeEnd));

  /// Пустой период (00:00 - 00:00)
  NsgTimeOfDayPeriod.empty() : this(const TimeOfDay(hour: 0, minute: 0), const TimeOfDay(hour: 0, minute: 0));

  /// Создание DateTime на основе даты
  DateTime beginDate(DateTime date) => DateTime(date.year, date.month, date.day, begin.hour, begin.minute);

  DateTime endDate(DateTime date) => DateTime(date.year, date.month, date.day, end.hour, end.minute);

  @override
  NsgTimeOfDayPeriod copyWithBegin(TimeOfDay begin) => NsgTimeOfDayPeriod(begin, end);

  @override
  NsgTimeOfDayPeriod copyWithEnd(TimeOfDay end) => NsgTimeOfDayPeriod(begin, end);

  /// Проверка на пустой период (00:00 - 00:00)
  @override
  bool get isEmpty => begin.isAtSameTimeAs(const TimeOfDay(hour: 0, minute: 0)) && end.isAtSameTimeAs(const TimeOfDay(hour: 0, minute: 0));
}

/// Период использующий время DateTime, использует время + дату
class NsgDateTimePeriod extends NsgPeriodNew<DateTime> {
  /// Основной конструктор с валидацией
  NsgDateTimePeriod(super.timeBegin, super.timeEnd);

  /// Пустой период (00:00:00 UTC 1 января 1970 года - 00:00:00 UTC 1 января 1970 года)
  NsgDateTimePeriod.empty() : this(DateTime(0), DateTime(0));

  NsgDateTimePeriod.time(DateTime date, TimeOfDay beginTime, TimeOfDay endTime)
    : this(
        DateTime(date.year, date.month, date.day, beginTime.hour, beginTime.minute),
        DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute),
      );

  /// Создание DateTime на основе даты
  TimeOfDay beginTime() => TimeOfDay(hour: begin.hour, minute: begin.minute);

  TimeOfDay endTime() => TimeOfDay(hour: end.hour, minute: end.minute);

  Duration get difference => end.difference(begin);

  @override
  NsgDateTimePeriod copyWithBegin(DateTime begin) => NsgDateTimePeriod(begin, end);

  @override
  NsgDateTimePeriod copyWithEnd(DateTime end) => NsgDateTimePeriod(begin, end);

  /// Проверка на пустой период (00:00:00 UTC 1 января 1970 года - 00:00:00 UTC 1 января 1970 года)
  @override
  bool get isEmpty => begin.compareTo(DateTime(0)) == 0 && end.compareTo(DateTime(0)) == 0;
}

extension TimeCount on NsgDateTimePeriod {
  /// получить дату с указанным временем (по умолчанию null = 00:00). Берётся остаток от dayNumber % daysNumber. dayNumber 0..days
  DateTime dateByDayNumber(int dayNumber, TimeOfDay? time) {
    final addedDate = begin.add(Duration(days: dayNumber));
    final date = DateTime(addedDate.year, addedDate.month, addedDate.day);
    if (time == null) return date;
    return date.add(Duration(hours: time.hour, minutes: time.minute));
  }

  /// получить номер дня относительно даты. Если date вне периода, то возвращаемый результат будет -1
  int dayNumberByDate(DateTime date) {
    if (!checkIn(date)) return -1;
    final dateWithoutTime = DateTime(date.year, date.month, date.day);
    final beginWithoutTime = DateTime(begin.year, begin.month, begin.day);
    return dateWithoutTime.difference(beginWithoutTime).inDays;
  }

  /// Количество дней в периоде включительно
  int get daysNumber {
    if (isEmpty) return 0;
    return difference.inDays + 1;
  }
}

/// day - период начала и конца дня. days - период, выбранный 2 разны днями
enum NsgPeriodGranularity { year, quarter, month, week, day, days, custom }

///Класс для задания фильтра по периоду. Используется, например, в фильтре контроллера данных
class NsgTypedPeriod extends NsgDateTimePeriod {
  final NsgPeriodGranularity type;

  NsgTypedPeriod(super.timeBegin, super.timeEnd) : type = defineType(timeBegin, timeEnd);

  factory NsgTypedPeriod.year(DateTime date) {
    final begin = Jiffy.parseFromDateTime(date).startOf(Unit.year).dateTime;
    final end = Jiffy.parseFromDateTime(begin).endOf(Unit.year).dateTime;
    return NsgTypedPeriod(begin, end);
  }
  factory NsgTypedPeriod.quarter(DateTime date) {
    final begin = Jiffy.parseFromDateTime(DateTime(date.year)).add(months: (getQuarter(date) - 1) * 3).dateTime;
    final end = Jiffy.parseFromDateTime(begin).add(months: 3).endOf(Unit.month).dateTime;
    return NsgTypedPeriod(begin, end);
  }

  factory NsgTypedPeriod.month(DateTime date) {
    final begin = Jiffy.parseFromDateTime(date).startOf(Unit.month).dateTime;
    final end = Jiffy.parseFromDateTime(begin).endOf(Unit.month).dateTime;
    return NsgTypedPeriod(begin, end);
  }

  factory NsgTypedPeriod.week(DateTime date) {
    final begin = Jiffy.parseFromDateTime(date).startOf(Unit.week).dateTime;
    final end = Jiffy.parseFromDateTime(begin).endOf(Unit.week).dateTime;
    return NsgTypedPeriod(begin, end);
  }
  factory NsgTypedPeriod.day(DateTime date) {
    final begin = Jiffy.parseFromDateTime(date).startOf(Unit.day).dateTime;
    final end = Jiffy.parseFromDateTime(begin).endOf(Unit.day).dateTime;
    return NsgTypedPeriod(begin, end);
  }

  factory NsgTypedPeriod.days(DateTime beginDate, DateTime endDate) {
    final begin = Jiffy.parseFromDateTime(beginDate).startOf(Unit.day).dateTime;
    final end = Jiffy.parseFromDateTime(endDate).endOf(Unit.day).dateTime;
    return NsgTypedPeriod(begin, end);
  }

  static int getQuarter(DateTime date) {
    return (date.month / 3).ceil();
  }

  static NsgPeriodGranularity defineType(DateTime timeBegin, DateTime timeEnd) {
    //Проверка на год
    if (Jiffy.parseFromDateTime(timeBegin).isSame(Jiffy.parseFromDateTime(timeBegin).startOf(Unit.year)) &&
        Jiffy.parseFromDateTime(timeEnd).isSame(Jiffy.parseFromDateTime(timeBegin).endOf(Unit.year))) {
      return NsgPeriodGranularity.year;
    }
    var qb = Jiffy.parseFromDateTime(DateTime(timeBegin.year)).add(months: (getQuarter(timeBegin) - 1) * 3);
    var qe = qb.add(months: 3).endOf(Unit.month);
    if (Jiffy.parseFromDateTime(timeBegin).isSame(qb) && Jiffy.parseFromDateTime(timeEnd).isSame(qe)) return NsgPeriodGranularity.quarter;
    //Проверка на месяц
    if (Jiffy.parseFromDateTime(timeBegin).isSame(Jiffy.parseFromDateTime(timeBegin).startOf(Unit.month)) &&
        Jiffy.parseFromDateTime(timeEnd).isSame(Jiffy.parseFromDateTime(timeBegin).endOf(Unit.month))) {
      return NsgPeriodGranularity.month;
    }
    //Проверка на неделю
    if (Jiffy.parseFromDateTime(timeBegin).isSame(Jiffy.parseFromDateTime(timeBegin).startOf(Unit.week)) &&
        Jiffy.parseFromDateTime(timeEnd).isSame(Jiffy.parseFromDateTime(timeBegin).endOf(Unit.week))) {
      return NsgPeriodGranularity.week;
    }
    //Проверка на день
    if (Jiffy.parseFromDateTime(timeBegin).isSame(Jiffy.parseFromDateTime(timeBegin).startOf(Unit.day)) &&
        Jiffy.parseFromDateTime(timeEnd).isSame(Jiffy.parseFromDateTime(timeBegin).endOf(Unit.day))) {
      return NsgPeriodGranularity.day;
    }
    // Проверка на дни
    if (Jiffy.parseFromDateTime(timeBegin).isSame(Jiffy.parseFromDateTime(timeBegin).startOf(Unit.day)) &&
        Jiffy.parseFromDateTime(timeEnd).isSame(Jiffy.parseFromDateTime(timeEnd).endOf(Unit.day))) {
      return NsgPeriodGranularity.days;
    }
    return NsgPeriodGranularity.custom;
  }

  @override
  NsgTypedPeriod copyWithBegin(DateTime begin) => NsgTypedPeriod(begin, end);

  @override
  NsgTypedPeriod copyWithEnd(DateTime end) => NsgTypedPeriod(begin, end);

  NsgTypedPeriod copyWithBeginTime(TimeOfDay beginTime) => NsgTypedPeriod(DateTime(begin.year, begin.month, begin.day, beginTime.hour, beginTime.minute), end);

  NsgTypedPeriod copyWithEndTime(TimeOfDay endTime) => NsgTypedPeriod(begin, DateTime(end.year, end.month, end.day, endTime.hour, endTime.minute));

  NsgTypedPeriod changeType(NsgPeriodGranularity newType) {
    final midPeriod = Jiffy.parseFromDateTime(begin).add(days: end.difference(begin).inDays ~/ 2).dateTime;
    switch (newType) {
      case NsgPeriodGranularity.year:
        return NsgTypedPeriod.year(midPeriod);
      case NsgPeriodGranularity.quarter:
        return NsgTypedPeriod.quarter(midPeriod);
      case NsgPeriodGranularity.month:
        return NsgTypedPeriod.month(midPeriod);
      case NsgPeriodGranularity.week:
        return NsgTypedPeriod.week(midPeriod);
      case NsgPeriodGranularity.day:
        return NsgTypedPeriod.day(midPeriod);
      case NsgPeriodGranularity.days:
        return NsgTypedPeriod.days(begin, end);
      case NsgPeriodGranularity.custom:
        return NsgTypedPeriod(begin, end);
    }
  }

  String dateText(bool withTime, String locale) {
    switch (type) {
      case NsgPeriodGranularity.year:
        return DateFormat.y(locale).format(begin);
      case NsgPeriodGranularity.quarter:
        return DateFormat.yQQQ(locale).format(begin);
      case NsgPeriodGranularity.month:
        return DateFormat.yMMM(locale).format(begin);
      case NsgPeriodGranularity.week:
        return '${DateFormat.yMd(locale).format(begin)} - ${DateFormat.yMd(locale).format(end)}';
      case NsgPeriodGranularity.day:
        return DateFormat.yMd(locale).format(begin);
      case NsgPeriodGranularity.days:
        return '${DateFormat.yMd(locale).format(begin)} - ${DateFormat.yMd(locale).format(end)}';
      case NsgPeriodGranularity.custom:
        return '${DateFormat.yMd(locale).add_jm().format(begin)} - ${DateFormat.yMd(locale).add_jm().format(end)}';
    }
  }

  @override
  String toString() => dateText(true, 'en');

  /// Добавить времени к началу и конца периода, либо предыдущий отрезок периода (для кастомного периода равняется количеству дней кастомного периода)
  NsgTypedPeriod add({Duration? time}) {
    if (time != null) return NsgTypedPeriod(begin.add(time), end.add(time));
    switch (type) {
      case NsgPeriodGranularity.year:
        return NsgTypedPeriod.year(Jiffy.parseFromDateTime(begin).add(years: 1).dateTime);
      case NsgPeriodGranularity.quarter:
        return NsgTypedPeriod.quarter(Jiffy.parseFromDateTime(begin).add(months: 3).dateTime);
      case NsgPeriodGranularity.month:
        return NsgTypedPeriod.month(Jiffy.parseFromDateTime(begin).add(months: 1).dateTime);
      case NsgPeriodGranularity.week:
        return NsgTypedPeriod.week(Jiffy.parseFromDateTime(begin).add(weeks: 1).dateTime);
      case NsgPeriodGranularity.day:
        return NsgTypedPeriod.day(Jiffy.parseFromDateTime(begin).add(days: 1).dateTime);
      case NsgPeriodGranularity.days:
        return NsgTypedPeriod.days(
          Jiffy.parseFromDateTime(begin).add(days: end.difference(begin).inDays).dateTime,
          Jiffy.parseFromDateTime(end).add(days: end.difference(begin).inDays).dateTime,
        );
      case NsgPeriodGranularity.custom:
        return NsgTypedPeriod.days(
          Jiffy.parseFromDateTime(begin).add(days: end.difference(begin).inDays).dateTime,
          Jiffy.parseFromDateTime(end).add(days: end.difference(begin).inDays).dateTime,
        );
    }
  }

  ///Выбрать предыдущий период
  ///Например, если период месяц - будет выбран предыдущий месяц
  NsgTypedPeriod sub({Duration? time}) {
    if (time != null) return NsgTypedPeriod(begin.add(time), end.add(time));
    switch (type) {
      case NsgPeriodGranularity.year:
        return NsgTypedPeriod.year(Jiffy.parseFromDateTime(begin).subtract(years: 1).dateTime);
      case NsgPeriodGranularity.quarter:
        return NsgTypedPeriod.quarter(Jiffy.parseFromDateTime(begin).subtract(months: 3).dateTime);
      case NsgPeriodGranularity.month:
        return NsgTypedPeriod.month(Jiffy.parseFromDateTime(begin).subtract(months: 1).dateTime);
      case NsgPeriodGranularity.week:
        return NsgTypedPeriod.week(Jiffy.parseFromDateTime(begin).subtract(weeks: 1).dateTime);
      case NsgPeriodGranularity.day:
        return NsgTypedPeriod.day(Jiffy.parseFromDateTime(begin).subtract(days: 1).dateTime);
      case NsgPeriodGranularity.days:
        return NsgTypedPeriod.days(
          Jiffy.parseFromDateTime(begin).subtract(days: end.difference(begin).inDays).dateTime,
          Jiffy.parseFromDateTime(end).subtract(days: end.difference(begin).inDays).dateTime,
        );
      case NsgPeriodGranularity.custom:
        return NsgTypedPeriod(
          Jiffy.parseFromDateTime(begin).subtract(days: end.difference(begin).inDays).dateTime,
          Jiffy.parseFromDateTime(end).subtract(days: end.difference(begin).inDays).dateTime,
        );
    }
  }
}

extension NsgTypedPeriodExtension on NsgTypedPeriod {
  NsgPeriod toNsgPeriod() {
    final period = NsgPeriod();
    period.beginDate = begin;
    period.endDate = end;
    return period;
  }

  DateTimeRange toDateTimeRange() {
    return DateTimeRange(start: begin, end: end);
  }

  NsgTimeOfDayPeriod toNsgTimeOfDayPeriod() {
    return NsgTimeOfDayPeriod(TimeOfDay.fromDateTime(begin), TimeOfDay.fromDateTime(end));
  }
}

extension NsgPeriodExtension on NsgPeriod {
  NsgTypedPeriod toNsgTypedPeriod() {
    final period = NsgTypedPeriod(beginDate, endDate);
    return period;
  }

  NsgTimeOfDayPeriod toNsgTimeOfDayPeriod() {
    return NsgTimeOfDayPeriod(TimeOfDay.fromDateTime(beginDate), TimeOfDay.fromDateTime(endDate));
  }
}

extension NsgTimeOfDayPeriodExtension on NsgTimeOfDayPeriod {
  NsgTypedPeriod toNsgTypedPeriod(DateTime? date) {
    date ??= DateTime.now();
    return NsgTypedPeriod(DateTime(date.year, date.month, date.day, begin.hour, begin.minute), DateTime(date.year, date.month, date.day, end.hour, end.minute));
  }
}
