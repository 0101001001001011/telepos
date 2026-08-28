import 'package:talker/talker.dart';

/// The application logger.
///
/// Lives here rather than in `main.dart` so that a screen wanting to log does
/// not have to import the entry point — which drags in the desktop window
/// manager, hardware and `dart:io`, none of which compile for a browser.
///
/// Entry points assign this during startup, before anything logs.
late Talker talker;

/// True once an entry point has assigned [talker]. Code that may run before
/// startup completes should check this rather than risk a late-init error.
bool get isLoggerReady => _assigned;
bool _assigned = false;

void installLogger(Talker instance) {
  talker = instance;
  _assigned = true;
}
