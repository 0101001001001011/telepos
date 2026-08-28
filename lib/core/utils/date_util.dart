import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class DateUtil {
  DateUtil._();

  static final _dateTimeFormat = DateFormat(AppConstants.dateTimeFormat);

  static final _dateFormat = DateFormat(AppConstants.dateFormat);

  static final _timeFormat = DateFormat(AppConstants.timeFormat);

  static final _timeShortFormat = DateFormat(AppConstants.timeFormatShort);

  static final _displayDateFormat = DateFormat(AppConstants.displayDateFormat);

  static final _displayDateTimeFormat = DateFormat(
    AppConstants.displayDateTimeFormat,
  );

  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  static String formatDate(DateTime date) => _dateFormat.format(date);

  static String formatTime(DateTime date) => _timeFormat.format(date);

  static String formatTimeShort(DateTime date) => _timeShortFormat.format(date);

  static String formatDisplayDate(DateTime date) =>
      _displayDateFormat.format(date);

  static String formatDisplayDateTime(DateTime date) =>
      _displayDateTimeFormat.format(date);

  static String format(DateTime date, String pattern) =>
      DateFormat(pattern).format(date);

  static DateTime? parseDateTime(String? str) {
    if (str == null || str.isEmpty) return null;
    try {
      return _dateTimeFormat.parse(str);
    } catch (_) {
      return null;
    }
  }

  static DateTime? parseDate(String? str) {
    if (str == null || str.isEmpty) return null;
    try {
      return _dateFormat.parse(str);
    } catch (_) {
      return null;
    }
  }

  static DateTime? parseIso(String? str) {
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  static DateTime startOfYear(DateTime date) => DateTime(date.year);

  static DateTime endOfYear(DateTime date) =>
      DateTime(date.year, 12, 31, 23, 59, 59, 999);

  static DateTime addDays(DateTime date, int days) =>
      date.add(Duration(days: days));

  static DateTime addMonths(DateTime date, int months) =>
      DateTime(date.year, date.month + months, date.day);

  static DateTime addYears(DateTime date, int years) =>
      DateTime(date.year + years, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isSameYear(DateTime a, DateTime b) => a.year == b.year;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isYesterday(DateTime date) =>
      isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

  static bool isTomorrow(DateTime date) =>
      isSameDay(date, DateTime.now().add(const Duration(days: 1)));

  static DateRange today() {
    final now = DateTime.now();
    return DateRange(start: startOfDay(now), end: endOfDay(now));
  }

  static DateRange yesterday() {
    final date = DateTime.now().subtract(const Duration(days: 1));
    return DateRange(start: startOfDay(date), end: endOfDay(date));
  }

  static DateRange thisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return DateRange(start: startOfDay(monday), end: endOfDay(sunday));
  }

  static DateRange thisMonth() {
    final now = DateTime.now();
    return DateRange(start: startOfMonth(now), end: endOfMonth(now));
  }

  static DateRange lastDays(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    return DateRange(start: startOfDay(start), end: endOfDay(now));
  }

  static String relativeTime(DateTime date, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final diff = now.difference(date);

    if (diff.isNegative) {
      final absDiff = date.difference(now);
      if (absDiff.inDays > 0) return 'через ${absDiff.inDays} дн.';
      if (absDiff.inHours > 0) return 'через ${absDiff.inHours} ч.';
      if (absDiff.inMinutes > 0) return 'через ${absDiff.inMinutes} мин.';
      return 'скоро';
    }

    if (diff.inDays > 30) return formatDisplayDate(date);
    if (diff.inDays > 0) return '${diff.inDays} дн. назад';
    if (diff.inHours > 0) return '${diff.inHours} ч. назад';
    if (diff.inMinutes > 0) return '${diff.inMinutes} мин. назад';
    return 'только что';
  }
}

class DateRange {
  const DateRange({required this.start, required this.end});

  final DateTime start;

  final DateTime end;

  Duration get duration => end.difference(start);

  int get days => duration.inDays;

  bool contains(DateTime date) =>
      date.isAfter(start) && date.isBefore(end) ||
      date.isAtSameMomentAs(start) ||
      date.isAtSameMomentAs(end);

  @override
  String toString() =>
      '${DateUtil.formatDate(start)} - ${DateUtil.formatDate(end)}';
}
