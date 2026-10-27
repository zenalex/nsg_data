import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nsg_data/helpers/nsg_period_new.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
  });

  test('day period text shows the weekday next to the date', () {
    final day = NsgTypedPeriod.day(DateTime(2026, 10, 26));
    expect(day.dateText(false, 'ru'), '26.10.2026, пн');
    expect(day.dateText(false, 'en'), '10/26/2026, Mon');
  });

  test('week period text is unchanged', () {
    final week = NsgTypedPeriod.week(DateTime(2026, 10, 26));
    expect(week.dateText(false, 'ru'), isNot(contains('пн')));
  });
}
