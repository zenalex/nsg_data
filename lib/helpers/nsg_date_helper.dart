abstract class NsgDateHelper {
  static final DateTime minDate = DateTime.utc(1754, 1, 1);
  static final DateTime emptyDateThreshold = minDate.add(const Duration(hours: 24));

  static bool isEmptyDate(DateTime? value) {
    if (value == null) return true;
    return !value.isAfter(emptyDateThreshold);
  }

  static DateTime clampToMinDate(DateTime value) {
    return isEmptyDate(value) ? minDate : value;
  }

  static DateTime? normalizeNullable(DateTime? value) {
    return isEmptyDate(value) ? null : value;
  }
}
