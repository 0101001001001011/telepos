import 'package:drift/drift.dart';

class TimestampConverter extends TypeConverter<DateTime, int> {
  const TimestampConverter();

  @override
  DateTime fromSql(int fromDb) {
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int toSql(DateTime value) {
    return value.millisecondsSinceEpoch;
  }
}

class NullableTimestampConverter extends TypeConverter<DateTime?, int?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromSql(int? fromDb) {
    if (fromDb == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int? toSql(DateTime? value) {
    return value?.millisecondsSinceEpoch;
  }
}

class DateTimeStringConverter extends TypeConverter<DateTime, String> {
  const DateTimeStringConverter();

  @override
  DateTime fromSql(String fromDb) {
    return DateTime.parse(fromDb);
  }

  @override
  String toSql(DateTime value) {
    return value.toIso8601String();
  }
}

class NullableDateTimeStringConverter
    extends TypeConverter<DateTime?, String?> {
  const NullableDateTimeStringConverter();

  @override
  DateTime? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) return null;
    return DateTime.tryParse(fromDb);
  }

  @override
  String? toSql(DateTime? value) {
    return value?.toIso8601String();
  }
}

class DurationSecondsConverter extends TypeConverter<Duration, int> {
  const DurationSecondsConverter();

  @override
  Duration fromSql(int fromDb) {
    return Duration(seconds: fromDb);
  }

  @override
  int toSql(Duration value) {
    return value.inSeconds;
  }
}

class DurationMillisConverter extends TypeConverter<Duration, int> {
  const DurationMillisConverter();

  @override
  Duration fromSql(int fromDb) {
    return Duration(milliseconds: fromDb);
  }

  @override
  int toSql(Duration value) {
    return value.inMilliseconds;
  }
}
