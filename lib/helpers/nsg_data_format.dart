import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'nsg_data_options.dart';

abstract class NsgDateFormat {
  static dateFormat(DateTime datetime, {String? format, bool ignoreYear = false}) {
    if (!ignoreYear && datetime.year <= 1754) {
      return "";
    }
    return DateFormat(format ?? NsgDataOptions.instance.dateformat, 'ru_RU').format(datetime);
  }

  static Duration timeToDuration(DateTime datetime) {
    DateTime date = DateTime(datetime.year, datetime.month, datetime.day);
    Duration duration = datetime.difference(date);
    return duration;
  }

  static String timeAgo(DateTime datetime, {String locale = 'ru', bool short = false}) {
    return timeago.format(datetime, locale: short ? '${locale}_short' : locale);
  }
}
