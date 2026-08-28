import 'package:flutter/foundation.dart';
import 'package:telepos/core/errors/safe_error_text.dart';

import 'setup_log_sink.dart';

class SetupLogger {
  SetupLogger._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final separator = '=' * 60;
    await SetupLogSink.open(
      '\n$separator\n'
      '  SETUP WIZARD SESSION: ${DateTime.now().toIso8601String()}\n'
      '  Platform: ${SetupLogSink.describeHost()}\n'
      '  Release: $kReleaseMode\n'
      '$separator\n\n',
    );
  }

  /// The file the log is going to, or null when it is going to a console.
  static String? get logFilePath => SetupLogSink.location;

  static void info(String message) {
    _write('INFO', message);
  }

  /// [error], если он есть, идёт в лог только через [safeErrorText] — тот
  /// же приём, что и у [SetupLogger.error] ниже (см. его докстринг про
  /// то, почему `toString()`/интерполяция произвольного исключения в
  /// строку не годится). Пункт 7 финальной волны закрытия долга
  /// безопасности (2026-08-22): правка «чиним метод, а не вызовы» дошла до
  /// [error], но не до этого метода — четыре места в
  /// `setup_repository_local.dart` интерполировали пойманное исключение в
  /// готовую строку (`'...: $e'`) до этой правки, тем же путём, который
  /// уже признан разрывом везде в этой работе. Секрета в этих четырёх
  /// точках сегодня нет (сток — местный файл, не провод и не сервер), но
  /// приём — тот же самый разрыв, который эта волна закрывает
  /// систематически, а не по факту находки.
  static void warning(String message, [Object? error]) {
    _write('WARN', message);
    if (error != null) {
      _write('WARN', '  Exception: ${safeErrorText(error)}');
    }
  }

  /// [error], если он есть, идёт в лог только через [safeErrorText] —
  /// **никогда** через `'$error'`/`toString()`. Не только `SqliteException`
  /// — параметры бы утекли, — но по тому же правилу и любой другой тип:
  /// `toString()` произвольного исключения не гарантированно безопасен, и
  /// доверять ему в вызывающем коде каждый раз заново дороже, чем не давать
  /// сюда сырой объект вовсе. Это то же решение, что уже принято для
  /// [data]/[_shouldMask], только на уровне всего метода, а не по ключу:
  /// у ошибки, в отличие от пары «ключ-значение» в [data], нет имени поля,
  /// по которому можно было бы решить, стоит ли маскировать.
  static void error(String message, [Object? error, StackTrace? stack]) {
    _write('ERROR', message);
    if (error != null) {
      _write('ERROR', '  Exception: ${safeErrorText(error)}');
    }
    if (stack != null) {
      _write('ERROR', '  StackTrace:\n$stack');
    }
  }

  static void step(String from, String to) {
    _write('STEP', '$from → $to');
  }

  static void validation(String field, bool passed, [String? detail]) {
    final status = passed ? 'OK' : 'FAIL';
    final extra = detail != null ? ' ($detail)' : '';
    _write('VALID', '[$status] $field$extra');
  }

  static void data(String label, Map<String, dynamic> values) {
    final buf = StringBuffer('$label: {');
    values.forEach((k, v) {
      final masked = _shouldMask(k) ? '***' : '$v';
      buf.write(' $k=$masked,');
    });
    buf.write(' }');
    _write('DATA', buf.toString());
  }

  static bool _shouldMask(String key) {
    final lower = key.toLowerCase();
    return lower.contains('pin') ||
        lower.contains('password') ||
        lower.contains('token') ||
        lower.contains('key') ||
        lower.contains('secret');
  }

  static void _write(String level, String message) {
    final now = DateTime.now();
    final ts =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';

    final line = '$ts $level  $message\n';

    SetupLogSink.write(line);

    if (kDebugMode) {
      debugPrint('[Setup/$level] $message');
    }
  }

  static Future<void> dispose() async {
    if (_initialized) {
      info('Setup logger closing');
      _initialized = false;
    }
  }
}
