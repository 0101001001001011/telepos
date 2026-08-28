import 'package:flutter/foundation.dart';

/// Sends the wizard's log to the browser console.
///
/// A browser has no file to append to, and it does not need one: the console is
/// where the person debugging is already looking, and it is what Playwright
/// reads back. The backend keeps its own log of what it was asked to do.
class SetupLogSink {
  /// Always null — there is no file. Callers show this to the operator when
  /// they offer to reveal the log, and skip the offer when it is absent.
  static String? get location => null;

  static Future<void> open(String header) async {
    debugPrint(header.trimRight());
  }

  static void write(String line) {
    debugPrint(line.trimRight());
  }

  static String describeHost() => 'browser';
}
