/// Spawning host commands and terminating the application.
///
/// Import this instead of `dart:io` for `Process` and `exit`. On web both are
/// impossible: the stand-ins report failure rather than throwing, and
/// [canRunProcesses] lets a caller hide a feature that cannot work there —
/// self-update, installer hand-off, the single-instance check.
library;

export 'host_process_native.dart'
    if (dart.library.js_interop) 'host_process_web.dart';
