/// Web has no window to size and no second instance to lock out — the browser
/// owns both. Every entry point here is a no-op so callers need no branch.
library;

Future<void> initWindow({bool isProduction = false}) async {}

/// Nothing to contend with: each tab is its own isolate of the application.
Future<bool> acquireSingleInstanceLock() async => true;

Future<void> releaseSingleInstanceLock() async {}
