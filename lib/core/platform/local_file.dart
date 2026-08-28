/// Local-file operations the UI needs, in a form that compiles for web.
///
/// Import this instead of `dart:io` when a screen shows a picked image or reads
/// a picked file. On native these are thin wrappers over `File`; on web they
/// work against the `blob:` URLs the pickers return, and the two operations a
/// browser genuinely cannot perform throw a message saying so rather than
/// failing obscurely.
library;

export 'local_file_native.dart'
    if (dart.library.js_interop) 'local_file_web.dart';
