// Which loader this build gets.
//
// The condition is `dart.library.ffi` and not `dart.library.io`: what decides
// is whether `dart:ffi` exists, and asking about anything else would be a
// proxy that can come apart.

export 'loader_web.dart' if (dart.library.ffi) 'loader_io.dart';
