import 'package:decimal/decimal.dart';

class DateTimeJsonConverter {
  const DateTimeJsonConverter._();

  static DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is DateTime) return json;
    if (json is String) return DateTime.tryParse(json);
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    return null;
  }

  static String? toJson(DateTime? value) {
    return value?.toIso8601String();
  }

  static DateTime fromJsonRequired(dynamic json) {
    final result = fromJson(json);
    if (result == null) {
      throw FormatException('Invalid DateTime: $json');
    }
    return result;
  }
}

class DurationJsonConverter {
  const DurationJsonConverter._();

  static Duration? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Duration) return json;
    if (json is int) return Duration(seconds: json);
    if (json is String) {
      final parsed = int.tryParse(json);
      if (parsed != null) return Duration(seconds: parsed);
    }
    return null;
  }

  static int? toJson(Duration? value) {
    return value?.inSeconds;
  }
}

class DecimalJsonConverter {
  const DecimalJsonConverter._();

  static Decimal? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Decimal) return json;
    if (json is String) return Decimal.tryParse(json);
    if (json is num) return Decimal.parse(json.toString());
    return null;
  }

  static String? toJson(Decimal? value) {
    return value?.toString();
  }

  static Decimal fromJsonRequired(dynamic json) {
    return fromJson(json) ?? Decimal.zero;
  }
}

class TimeOfDayJsonConverter {
  const TimeOfDayJsonConverter._();

  static Duration? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Duration) return json;
    if (json is String) {
      final parts = json.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
        return Duration(hours: hour, minutes: minute, seconds: second);
      }
    }
    if (json is int) {
      return Duration(minutes: json);
    }
    return null;
  }

  static String? toJson(Duration? value) {
    if (value == null) return null;
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class BoolIntJsonConverter {
  const BoolIntJsonConverter._();

  static bool fromJson(dynamic json) {
    if (json == null) return false;
    if (json is bool) return json;
    if (json is int) return json != 0;
    if (json is String) {
      return json == '1' || json.toLowerCase() == 'true';
    }
    return false;
  }

  static int toJson(bool value) {
    return value ? 1 : 0;
  }
}

class StringListJsonConverter {
  const StringListJsonConverter._();

  static List<String> fromJson(dynamic json) {
    if (json == null) return [];
    if (json is List) return json.map((e) => e.toString()).toList();
    if (json is String) {
      if (json.isEmpty) return [];
      return json.split(',').map((s) => s.trim()).toList();
    }
    return [];
  }

  static dynamic toJson(List<String>? value, {bool asString = false}) {
    if (value == null || value.isEmpty) return asString ? '' : [];
    return asString ? value.join(',') : value;
  }
}
