/// The raw `dart:ffi` lookups. Nothing here interprets anything.
///
/// Kept apart from [RkSyslogSink] so the interesting file has no `Pointer` in
/// it and this one has no policy in it.
///
/// **Not exported.** The public surface of this package is Dart types; a
/// caller that reached these would be holding native pointers whose freeing
/// rules are the ones in the crate's `ffi` module, and getting that wrong is
/// how И146 turns into a leak nobody notices for a year.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Opaque native handles. Never dereferenced on this side.
final class RkConfigHandle extends Opaque {}

final class RkSdHandle extends Opaque {}

final class RkSinkHandle extends Opaque {}

typedef _VersionC = Pointer<Utf8> Function();
typedef _StatusNameC = Pointer<Utf8> Function(Int32);
typedef RkStatusNameDart = Pointer<Utf8> Function(int);
typedef _StringFreeC = Void Function(Pointer<Utf8>);
typedef RkStringFreeDart = void Function(Pointer<Utf8>);
typedef _NameAtC = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef RkNameAtDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef _NameValueC = Int32 Function(Pointer<Utf8>, Pointer<Int32>);
typedef RkNameValueDart = int Function(Pointer<Utf8>, Pointer<Int32>);

typedef _ConfigNewC = Pointer<RkConfigHandle> Function();
typedef _ConfigSetC =
    Int32 Function(
      Pointer<RkConfigHandle>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkConfigSetDart =
    int Function(
      Pointer<RkConfigHandle>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef _ConfigFreeC = Void Function(Pointer<RkConfigHandle>);
typedef RkConfigFreeDart = void Function(Pointer<RkConfigHandle>);

typedef _SdNewC = Pointer<RkSdHandle> Function();
typedef _SdElementC =
    Int32 Function(Pointer<RkSdHandle>, Pointer<Utf8>, Pointer<Pointer<Utf8>>);
typedef RkSdElementDart =
    int Function(Pointer<RkSdHandle>, Pointer<Utf8>, Pointer<Pointer<Utf8>>);
typedef _SdParamC =
    Int32 Function(
      Pointer<RkSdHandle>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkSdParamDart =
    int Function(
      Pointer<RkSdHandle>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef _SdClearC = Int32 Function(Pointer<RkSdHandle>);
typedef RkSdClearDart = int Function(Pointer<RkSdHandle>);
typedef _SdFreeC = Void Function(Pointer<RkSdHandle>);
typedef RkSdFreeDart = void Function(Pointer<RkSdHandle>);

typedef _OpenC =
    Int32 Function(
      Pointer<RkConfigHandle>,
      Pointer<Pointer<RkSinkHandle>>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkOpenDart =
    int Function(
      Pointer<RkConfigHandle>,
      Pointer<Pointer<RkSinkHandle>>,
      Pointer<Pointer<Utf8>>,
    );

typedef _SubmitC =
    Int32 Function(
      Pointer<RkSinkHandle>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int64,
      Int32,
      Pointer<Utf8>,
      Pointer<RkSdHandle>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkSubmitDart =
    int Function(
      Pointer<RkSinkHandle>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
      Pointer<Utf8>,
      Pointer<RkSdHandle>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );

typedef _FlushC =
    Int32 Function(Pointer<RkSinkHandle>, Int32, Pointer<Pointer<Utf8>>);
typedef RkFlushDart =
    int Function(Pointer<RkSinkHandle>, int, Pointer<Pointer<Utf8>>);
typedef _StatC =
    Int32 Function(
      Pointer<RkSinkHandle>,
      Pointer<Utf8>,
      Pointer<Int64>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkStatDart =
    int Function(
      Pointer<RkSinkHandle>,
      Pointer<Utf8>,
      Pointer<Int64>,
      Pointer<Pointer<Utf8>>,
    );
typedef _CloseC = Void Function(Pointer<RkSinkHandle>);
typedef RkCloseDart = void Function(Pointer<RkSinkHandle>);
typedef _ProvokePanicC = Int32 Function(Pointer<Pointer<Utf8>>);
typedef RkProvokePanicDart = int Function(Pointer<Pointer<Utf8>>);

/// Every symbol, resolved once.
class RkSyslogBindings {
  RkSyslogBindings(this.library)
    : version = library.lookupFunction<_VersionC, _VersionC>(
        'rk_syslog_version',
      ),
      statusName = library.lookupFunction<_StatusNameC, RkStatusNameDart>(
        'rk_syslog_status_name',
      ),
      stringFree = library.lookupFunction<_StringFreeC, RkStringFreeDart>(
        'rk_syslog_string_free',
      ),
      nameAt = library.lookupFunction<_NameAtC, RkNameAtDart>(
        'rk_syslog_name_at',
      ),
      severityValue = library.lookupFunction<_NameValueC, RkNameValueDart>(
        'rk_syslog_severity_value',
      ),
      facilityValue = library.lookupFunction<_NameValueC, RkNameValueDart>(
        'rk_syslog_facility_value',
      ),
      configNew = library.lookupFunction<_ConfigNewC, _ConfigNewC>(
        'rk_syslog_config_new',
      ),
      configSet = library.lookupFunction<_ConfigSetC, RkConfigSetDart>(
        'rk_syslog_config_set',
      ),
      configFree = library.lookupFunction<_ConfigFreeC, RkConfigFreeDart>(
        'rk_syslog_config_free',
      ),
      sdNew = library.lookupFunction<_SdNewC, _SdNewC>('rk_syslog_sd_new'),
      sdElement = library.lookupFunction<_SdElementC, RkSdElementDart>(
        'rk_syslog_sd_element',
      ),
      sdParam = library.lookupFunction<_SdParamC, RkSdParamDart>(
        'rk_syslog_sd_param',
      ),
      sdClear = library.lookupFunction<_SdClearC, RkSdClearDart>(
        'rk_syslog_sd_clear',
      ),
      sdFree = library.lookupFunction<_SdFreeC, RkSdFreeDart>(
        'rk_syslog_sd_free',
      ),
      open = library.lookupFunction<_OpenC, RkOpenDart>('rk_syslog_open'),
      submit = library.lookupFunction<_SubmitC, RkSubmitDart>(
        'rk_syslog_submit',
      ),
      flush = library.lookupFunction<_FlushC, RkFlushDart>('rk_syslog_flush'),
      stat = library.lookupFunction<_StatC, RkStatDart>('rk_syslog_stat'),
      close = library.lookupFunction<_CloseC, RkCloseDart>('rk_syslog_close'),
      provokePanic = library.lookupFunction<_ProvokePanicC, RkProvokePanicDart>(
        'rk_syslog_provoke_panic',
      );

  final DynamicLibrary library;

  final Pointer<Utf8> Function() version;
  final RkStatusNameDart statusName;
  final RkStringFreeDart stringFree;
  final RkNameAtDart nameAt;
  final RkNameValueDart severityValue;
  final RkNameValueDart facilityValue;
  final Pointer<RkConfigHandle> Function() configNew;
  final RkConfigSetDart configSet;
  final RkConfigFreeDart configFree;
  final Pointer<RkSdHandle> Function() sdNew;
  final RkSdElementDart sdElement;
  final RkSdParamDart sdParam;
  final RkSdClearDart sdClear;
  final RkSdFreeDart sdFree;
  final RkOpenDart open;
  final RkSubmitDart submit;
  final RkFlushDart flush;
  final RkStatDart stat;
  final RkCloseDart close;
  final RkProvokePanicDart provokePanic;
}

/// The file name of the shared library on this platform.
String rkSyslogLibraryFileName() {
  if (Platform.isWindows) return 'rk_syslog.dll';
  if (Platform.isMacOS || Platform.isIOS) return 'librk_syslog.dylib';
  return 'librk_syslog.so';
}

/// Finds and opens the native library, or returns `null`.
///
/// Returns rather than throws, so a caller can ask "is the sink available"
/// and get an answer instead of a stack trace. In a Flutter build the
/// per-platform wiring puts the library where the system loader finds it;
/// [explicitPath] and `RK_SYSLOG_LIB` are how a caller points at a different
/// one.
DynamicLibrary? openRkSyslogLibrary({String? explicitPath}) {
  final fromEnvironment = Platform.environment['RK_SYSLOG_LIB'];
  final candidates = <String>[
    ?explicitPath,
    if (fromEnvironment != null && fromEnvironment.isNotEmpty) fromEnvironment,
    rkSyslogLibraryFileName(),
  ];
  for (final candidate in candidates) {
    try {
      return DynamicLibrary.open(candidate);
    } on ArgumentError {
      continue;
    } on Object {
      continue;
    }
  }
  // Statically linked into the host process is a normal outcome on iOS and
  // for a staticlib build, so it is tried last rather than not at all.
  try {
    final process = DynamicLibrary.process();
    process.lookup<NativeFunction<_VersionC>>('rk_syslog_version');
    return process;
  } on Object {
    return null;
  }
}
