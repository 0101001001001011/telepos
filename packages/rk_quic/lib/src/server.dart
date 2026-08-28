// Which endpoint implementation this build gets.
//
// The condition is `dart.library.ffi` — what decides is whether `dart:ffi`
// exists, and anything else would be a proxy that can come apart.

export 'server_web.dart' if (dart.library.ffi) 'server_io.dart';
