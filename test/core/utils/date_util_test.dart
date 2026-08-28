import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/utils/date_util.dart';

void main() {
  group('DateUtil', () {
    group('formatting', () {
      test('formatDateTime formats as yyyy-MM-dd HH:mm', () {
        final date = DateTime(2024, 3, 15, 14, 30);
        expect(DateUtil.formatDateTime(date), '2024-03-15 14:30');
      });

      test('formatDate formats as yyyy-MM-dd', () {
        final date = DateTime(2024, 3, 15);
        expect(DateUtil.formatDate(date), '2024-03-15');
      });

      test('formatTime formats as HH:mm:ss', () {
        final date = DateTime(2024, 3, 15, 14, 30, 45);
        expect(DateUtil.formatTime(date), '14:30:45');
      });

      test('formatTimeShort formats as HH:mm', () {
        final date = DateTime(2024, 3, 15, 14, 30, 45);
        expect(DateUtil.formatTimeShort(date), '14:30');
      });

      test('formatDisplayDate formats as dd.MM.yyyy', () {
        final date = DateTime(2024, 3, 15);
        expect(DateUtil.formatDisplayDate(date), '15.03.2024');
      });

      test('formatDisplayDateTime formats as dd.MM.yyyy HH:mm', () {
        final date = DateTime(2024, 3, 15, 14, 30);
        expect(DateUtil.formatDisplayDateTime(date), '15.03.2024 14:30');
      });

      test('format with custom pattern', () {
        final date = DateTime(2024, 3, 15, 14, 30);
        expect(DateUtil.format(date, 'MM/dd/yyyy'), '03/15/2024');
      });
    });

    group('parsing', () {
      test('parseDateTime parses yyyy-MM-dd HH:mm', () {
        final result = DateUtil.parseDateTime('2024-03-15 14:30');
        expect(result, DateTime(2024, 3, 15, 14, 30));
      });

      test('parseDateTime returns null for null', () {
        expect(DateUtil.parseDateTime(null), isNull);
      });

      test('parseDateTime returns null for empty', () {
        expect(DateUtil.parseDateTime(''), isNull);
      });

      test('parseDateTime returns null for invalid', () {
        expect(DateUtil.parseDateTime('invalid'), isNull);
      });

      test('parseDate parses yyyy-MM-dd', () {
        final result = DateUtil.parseDate('2024-03-15');
        expect(result, DateTime(2024, 3, 15));
      });

      test('parseDate returns null for invalid', () {
        expect(DateUtil.parseDate('invalid'), isNull);
        expect(DateUtil.parseDate(null), isNull);
      });

      test('parseIso parses ISO 8601', () {
        final result = DateUtil.parseIso('2024-03-15T14:30:00.000Z');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
      });

      test('parseIso returns null for invalid', () {
        expect(DateUtil.parseIso('invalid'), isNull);
        expect(DateUtil.parseIso(null), isNull);
      });
    });

    group('date calculations', () {
      test('startOfDay returns 00:00:00', () {
        final date = DateTime(2024, 3, 15, 14, 30, 45);
        final result = DateUtil.startOfDay(date);
        expect(result, DateTime(2024, 3, 15));
        expect(result.hour, 0);
        expect(result.minute, 0);
        expect(result.second, 0);
      });

      test('endOfDay returns 23:59:59.999', () {
        final date = DateTime(2024, 3, 15, 14, 30);
        final result = DateUtil.endOfDay(date);
        expect(result.hour, 23);
        expect(result.minute, 59);
        expect(result.second, 59);
        expect(result.millisecond, 999);
      });

      test('startOfMonth returns first day', () {
        final date = DateTime(2024, 3, 15);
        final result = DateUtil.startOfMonth(date);
        expect(result, DateTime(2024, 3, 1));
      });

      test('endOfMonth returns last day', () {
        final date = DateTime(2024, 3, 15);
        final result = DateUtil.endOfMonth(date);
        expect(result.day, 31);
        expect(result.hour, 23);
        expect(result.minute, 59);
      });

      test('endOfMonth handles February', () {
        final date = DateTime(2024, 2, 15);
        final result = DateUtil.endOfMonth(date);
        expect(result.day, 29);
      });

      test('startOfYear returns Jan 1', () {
        final date = DateTime(2024, 6, 15);
        final result = DateUtil.startOfYear(date);
        expect(result, DateTime(2024, 1, 1));
      });

      test('endOfYear returns Dec 31 23:59:59', () {
        final date = DateTime(2024, 6, 15);
        final result = DateUtil.endOfYear(date);
        expect(result.month, 12);
        expect(result.day, 31);
        expect(result.hour, 23);
      });

      test('addDays adds days', () {
        final date = DateTime(2024, 3, 15);
        expect(DateUtil.addDays(date, 5), DateTime(2024, 3, 20));
        expect(DateUtil.addDays(date, -5), DateTime(2024, 3, 10));
      });

      test('addMonths adds months', () {
        final date = DateTime(2024, 3, 15);
        expect(DateUtil.addMonths(date, 2), DateTime(2024, 5, 15));
        expect(DateUtil.addMonths(date, -1), DateTime(2024, 2, 15));
      });

      test('addYears adds years', () {
        final date = DateTime(2024, 3, 15);
        expect(DateUtil.addYears(date, 1), DateTime(2025, 3, 15));
        expect(DateUtil.addYears(date, -2), DateTime(2022, 3, 15));
      });
    });

    group('comparisons', () {
      test('isSameDay', () {
        final a = DateTime(2024, 3, 15, 10, 0);
        final b = DateTime(2024, 3, 15, 20, 0);
        final c = DateTime(2024, 3, 16, 10, 0);
        expect(DateUtil.isSameDay(a, b), true);
        expect(DateUtil.isSameDay(a, c), false);
      });

      test('isSameMonth', () {
        final a = DateTime(2024, 3, 1);
        final b = DateTime(2024, 3, 31);
        final c = DateTime(2024, 4, 1);
        expect(DateUtil.isSameMonth(a, b), true);
        expect(DateUtil.isSameMonth(a, c), false);
      });

      test('isSameYear', () {
        final a = DateTime(2024, 1, 1);
        final b = DateTime(2024, 12, 31);
        final c = DateTime(2025, 1, 1);
        expect(DateUtil.isSameYear(a, b), true);
        expect(DateUtil.isSameYear(a, c), false);
      });

      test('isToday', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 12, 0);
        final yesterday = today.subtract(const Duration(days: 1));
        expect(DateUtil.isToday(today), true);
        expect(DateUtil.isToday(yesterday), false);
      });

      test('isYesterday', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        expect(DateUtil.isYesterday(yesterday), true);
        expect(DateUtil.isYesterday(now), false);
      });

      test('isTomorrow', () {
        final now = DateTime.now();
        final tomorrow = now.add(const Duration(days: 1));
        expect(DateUtil.isTomorrow(tomorrow), true);
        expect(DateUtil.isTomorrow(now), false);
      });
    });

    group('date ranges', () {
      test('today returns correct range', () {
        final range = DateUtil.today();
        final now = DateTime.now();
        expect(range.start.day, now.day);
        expect(range.end.day, now.day);
        expect(range.start.hour, 0);
        expect(range.end.hour, 23);
      });

      test('yesterday returns correct range', () {
        final range = DateUtil.yesterday();
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(range.start.day, yesterday.day);
        expect(range.end.day, yesterday.day);
      });

      test('thisWeek returns Monday to Sunday', () {
        final range = DateUtil.thisWeek();
        expect(range.start.weekday, DateTime.monday);
        expect(range.days, greaterThanOrEqualTo(6));
      });

      test('thisMonth returns correct range', () {
        final range = DateUtil.thisMonth();
        final now = DateTime.now();
        expect(range.start.day, 1);
        expect(range.start.month, now.month);
        expect(range.end.month, now.month);
      });

      test('lastDays returns correct range', () {
        final range = DateUtil.lastDays(7);
        expect(range.days, greaterThanOrEqualTo(6));
        expect(range.days, lessThanOrEqualTo(7));
      });
    });

    group('relativeTime', () {
      test('returns "только что" for recent past', () {
        final now = DateTime.now();
        final recent = now.subtract(const Duration(seconds: 30));
        expect(DateUtil.relativeTime(recent, from: now), 'только что');
      });

      test('returns minutes for past < 1 hour', () {
        final now = DateTime.now();
        final past = now.subtract(const Duration(minutes: 5));
        expect(DateUtil.relativeTime(past, from: now), '5 мин. назад');
      });

      test('returns hours for past < 1 day', () {
        final now = DateTime.now();
        final past = now.subtract(const Duration(hours: 3));
        expect(DateUtil.relativeTime(past, from: now), '3 ч. назад');
      });

      test('returns days for past < 30 days', () {
        final now = DateTime.now();
        final past = now.subtract(const Duration(days: 5));
        expect(DateUtil.relativeTime(past, from: now), '5 дн. назад');
      });

      test('returns formatted date for old dates', () {
        final now = DateTime.now();
        final past = now.subtract(const Duration(days: 45));
        expect(DateUtil.relativeTime(past, from: now), contains('.'));
      });

      test('returns future time', () {
        final now = DateTime.now();
        final future = now.add(const Duration(hours: 2));
        expect(DateUtil.relativeTime(future, from: now), 'через 2 ч.');
      });

      test('returns "скоро" for near future', () {
        final now = DateTime.now();
        final future = now.add(const Duration(seconds: 30));
        expect(DateUtil.relativeTime(future, from: now), 'скоро');
      });
    });
  });

  group('DateRange', () {
    test('duration calculates correctly', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 10),
      );
      expect(range.duration.inDays, 9);
    });

    test('days returns correct count', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 8),
      );
      expect(range.days, 7);
    });

    test('contains returns true for date in range', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 10),
      );
      expect(range.contains(DateTime(2024, 3, 5)), true);
    });

    test('contains returns true for start date', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 10),
      );
      expect(range.contains(DateTime(2024, 3, 1)), true);
    });

    test('contains returns true for end date', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 10),
      );
      expect(range.contains(DateTime(2024, 3, 10)), true);
    });

    test('contains returns false for date outside range', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 10),
      );
      expect(range.contains(DateTime(2024, 3, 15)), false);
      expect(range.contains(DateTime(2024, 2, 15)), false);
    });

    test('toString formats correctly', () {
      final range = DateRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 10),
      );
      expect(range.toString(), '2024-03-01 - 2024-03-10');
    });
  });
}
