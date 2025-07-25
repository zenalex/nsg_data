import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'nsg_data_options.dart';

abstract class NsgDateFormat {
  static dateFormat(DateTime datetime, {String? format, bool ignoreYear = false, required String locale}) {
    if (!ignoreYear && datetime.year <= 1754) {
      return "";
    }
    return DateFormat(format ?? NsgDataOptions.instance.dateformat, locale).format(datetime);
  }

  static Duration timeToDuration(DateTime datetime) {
    DateTime date = DateTime(datetime.year, datetime.month, datetime.day);
    Duration duration = datetime.difference(date);
    return duration;
  }

  /// Прошедшее время в виде "1 сек назад", "2 недели назад", "1 месяца назад"
  /// allowFromNow=true - когда про будущее время, без слова "назад"
  static String timeAgo(DateTime datetime, {String locale = 'ru', bool short = false, bool allowFromNow = false}) {
    return timeago.format(datetime, locale: short ? '${locale}_short' : locale, allowFromNow: allowFromNow);
  }
}
