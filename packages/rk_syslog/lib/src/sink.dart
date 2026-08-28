/// The Dart face of the sink.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'severity.dart';
import 'status.dart';
import 'structured_data.dart';

/// A configuration, built one named key at a time.
///
/// Named keys, not a constructor with twenty optional arguments, because the
/// native side answers `unknownConfigKey` for a name it does not know — so a
/// key that this package has not heard of yet still reaches the library, and
/// a misspelled one is refused rather than ignored.
///
/// The keys, with their defaults, are listed in the README. `spool_dir` is
/// the only one that has no default.
class RkSyslogConfig {
  RkSyslogConfig({required String spoolDirectory}) {
    _values['spool_dir'] = spoolDirectory;
  }

  final Map<String, String> _values = {};

  /// Sets a key. Whether it is a key the library knows is the library's
  /// answer, given when the sink opens.
  void set(String key, String value) => _values[key] = value;

  /// Convenience for the three header fields every record carries.
  void identify({String? hostName, String? appName, String? procId}) {
    if (hostName != null) _values['host_name'] = hostName;
    if (appName != null) _values['app_name'] = appName;
    if (procId != null) _values['proc_id'] = procId;
  }

  /// The default facility for records that do not name one.
  set facility(RkFacility facility) => _values['facility'] = facility.wireName;

  /// An unmodifiable view, for tests and for logging what was asked for.
  Map<String, String> get entries => Map.unmodifiable(_values);
}

/// A running syslog sink.
///
/// # Which isolate
///
/// И145: no call into a native library runs on the interface isolate.
/// [submit] is cheap and never waits on a network, but it is still a foreign
/// call and belongs on a worker isolate with everything else in the layer
/// below the contract. [flush] blocks on purpose and must never be anywhere
/// near the interface.
///
/// # What it guarantees
///
/// Records leave in the order they were submitted, across a restart, and are
/// delivered **at least once** — see the crate documentation for why syslog
/// cannot promise exactly once.
class RkSyslogSink {
  RkSyslogSink._(this._bindings, this._handle);

  final RkSyslogBindings _bindings;
  Pointer<RkSinkHandle> _handle;
  bool _closed = false;

  /// Whether the native library can be loaded in this build.
  ///
  /// Answers rather than throws: a web build, or a build whose native library
  /// has not been wired up yet, gets `false` and can say so in its own words.
  static bool isAvailable({String? libraryPath}) =>
      openRkSyslogLibrary(explicitPath: libraryPath) != null;

  /// The version of the loaded native library, or `null` if there is none.
  static String? nativeVersion({String? libraryPath}) {
    final library = openRkSyslogLibrary(explicitPath: libraryPath);
    if (library == null) return null;
    return RkSyslogBindings(library).version().toDartString();
  }

  /// Opens a sink.
  ///
  /// Everything the native side can check up front — the spool directory, the
  /// bound, the certificates, every configuration value — is checked here, so
  /// a mistake surfaces once at startup rather than on every record.
  static RkSyslogResult<RkSyslogSink> open(
    RkSyslogConfig config, {
    String? libraryPath,
  }) {
    final library = openRkSyslogLibrary(explicitPath: libraryPath);
    if (library == null) {
      return RkSyslogFailure(
        RkSyslogStatus.unrecognised,
        'the rk_syslog native library could not be loaded; looked for '
        '${rkSyslogLibraryFileName()}, the RK_SYSLOG_LIB environment '
        'variable, and symbols already in this process',
      );
    }
    final RkSyslogBindings bindings;
    try {
      bindings = RkSyslogBindings(library);
    } on ArgumentError catch (error) {
      return RkSyslogFailure(
        RkSyslogStatus.unrecognised,
        'the loaded library is missing a symbol this package needs, so it is '
        'not the rk_syslog this binding was built against: $error',
      );
    }

    final handle = bindings.configNew();
    if (handle == nullptr) {
      return const RkSyslogFailure(
        RkSyslogStatus.panicked,
        'the native library could not allocate a configuration',
      );
    }
    try {
      for (final entry in config.entries.entries) {
        final outcome = _call(
          bindings,
          (error) => _withStrings(
            [entry.key, entry.value],
            (pointers) =>
                bindings.configSet(handle, pointers[0], pointers[1], error),
          ),
        );
        if (outcome case final RkSyslogFailure<void> failure) {
          return failure.cast<RkSyslogSink>();
        }
      }

      final out = calloc<Pointer<RkSinkHandle>>();
      try {
        final outcome = _call(
          bindings,
          (error) => bindings.open(handle, out, error),
        );
        if (outcome case final RkSyslogFailure<void> failure) {
          return failure.cast<RkSyslogSink>();
        }
        return RkSyslogOk(RkSyslogSink._(bindings, out.value));
      } finally {
        calloc.free(out);
      }
    } finally {
      // Ours to free: we made it (И146). The native side only read it.
      bindings.configFree(handle);
    }
  }

  /// Submits one record.
  ///
  /// Frames it and hands it to the worker. Does not touch the disk or the
  /// network on this thread — a collector that is down cannot slow this down.
  ///
  /// A record that cannot be framed comes back as a failure, here, now, with
  /// the offending field named. It is never quietly dropped.
  ///
  /// [timestamp] defaults to now, with this machine's UTC offset.
  RkSyslogResult<void> submit({
    required RkSeverity severity,
    String? message,
    RkFacility? facility,
    DateTime? timestamp,
    String? msgid,
    RkStructuredData? structuredData,
  }) {
    if (_closed) {
      return const RkSyslogFailure(
        RkSyslogStatus.closed,
        'this sink has been closed',
      );
    }
    final when = timestamp ?? DateTime.now();
    final micros = when.toUtc().microsecondsSinceEpoch;
    final offsetMinutes = when.isUtc ? 0 : when.timeZoneOffset.inMinutes;

    Pointer<RkSdHandle> sd = nullptr;
    try {
      if (structuredData != null && structuredData.isNotEmpty) {
        sd = _bindings.sdNew();
        if (sd == nullptr) {
          return const RkSyslogFailure(
            RkSyslogStatus.panicked,
            'the native library could not allocate structured data',
          );
        }
        final built = structuredData.writeInto(_bindings, sd);
        if (built case final RkSyslogFailure<void> failure) {
          return failure;
        }
      }
      return _call(
        _bindings,
        (error) => _withStrings(
          [severity.wireName, facility?.wireName, msgid, message],
          (pointers) => _bindings.submit(
            _handle,
            pointers[0],
            pointers[1],
            micros,
            offsetMinutes,
            pointers[2],
            sd,
            pointers[3],
            error,
          ),
        ),
      );
    } finally {
      if (sd != nullptr) _bindings.sdFree(sd);
    }
  }

  /// Waits until everything submitted so far has reached the spool.
  ///
  /// **Blocks.** The only call here that does, and only the isolate that asks.
  /// Use it at shutdown, and wherever a record must be on disk before the next
  /// thing happens. It says nothing about delivery: a collector may be
  /// unreachable for a week and this still returns.
  RkSyslogResult<void> flush({Duration timeout = const Duration(seconds: 5)}) {
    if (_closed) {
      return const RkSyslogFailure(
        RkSyslogStatus.closed,
        'this sink has been closed',
      );
    }
    return _call(
      _bindings,
      (error) => _bindings.flush(_handle, timeout.inMilliseconds, error),
    );
  }

  /// Reads a counter by name.
  ///
  /// An unknown name comes back as [RkSyslogStatus.unknownStat], not as zero:
  /// "not measured" and "measured, and none" are different answers and a
  /// dashboard that confuses them is worse than one with a gap in it.
  ///
  /// The names are listed in the README; [counterNames] asks the library.
  RkSyslogResult<int> stat(String name) {
    if (_closed) {
      return const RkSyslogFailure(
        RkSyslogStatus.closed,
        'this sink has been closed',
      );
    }
    final out = calloc<Int64>();
    try {
      final outcome = _call(
        _bindings,
        (error) => _withStrings([
          name,
        ], (pointers) => _bindings.stat(_handle, pointers[0], out, error)),
      );
      return switch (outcome) {
        RkSyslogOk<void>() => RkSyslogOk(out.value),
        final RkSyslogFailure<void> failure => failure.cast<int>(),
      };
    } finally {
      calloc.free(out);
    }
  }

  /// Every counter name the loaded library publishes.
  List<String> get counterNames => _names(_bindings, 'counter');

  /// Every configuration key the loaded library accepts.
  List<String> get configKeys => _names(_bindings, 'config_key');

  /// Closes the sink: stops accepting, waits for the worker to finish writing
  /// what it accepted, then frees.
  ///
  /// Deterministic, and it must be called (И146). Dart's collector does not
  /// know about the spool, the worker thread or the socket, and will not
  /// close them for you. Calling it twice is safe.
  void close() {
    if (_closed) return;
    _closed = true;
    _bindings.close(_handle);
    _handle = nullptr;
  }

  /// Checks this package's name tables against the loaded library's.
  ///
  /// The reason enums cross by name (И147) is that the two sides can be
  /// compared. This is the comparison. It returns the disagreements; an empty
  /// list means the tables match.
  static List<String> verifyNameTables({String? libraryPath}) {
    final library = openRkSyslogLibrary(explicitPath: libraryPath);
    if (library == null) return const ['the native library is not loaded'];
    final bindings = RkSyslogBindings(library);
    final problems = <String>[];

    void compare(String kind, List<String> ours) {
      final theirs = _names(bindings, kind);
      for (final name in ours) {
        if (!theirs.contains(name)) {
          problems.add(
            "this package knows '$name' as a $kind; the library "
            'does not',
          );
        }
      }
      for (final name in theirs) {
        if (!ours.contains(name)) {
          problems.add(
            "the library knows '$name' as a $kind; this package "
            'does not',
          );
        }
      }
    }

    compare('severity', [for (final s in RkSeverity.values) s.wireName]);
    compare('facility', [for (final f in RkFacility.values) f.wireName]);
    compare('status', [
      for (final s in RkSyslogStatus.values)
        if (s != RkSyslogStatus.unrecognised) s.wireName,
    ]);

    // Names agreeing is not enough: the numbers behind them must agree too,
    // or a record would carry the right word and the wrong PRI.
    final out = calloc<Int32>();
    try {
      for (final severity in RkSeverity.values) {
        final name = severity.wireName.toNativeUtf8();
        try {
          if (bindings.severityValue(name, out) != 0 ||
              out.value != severity.code) {
            problems.add(
              "severity '${severity.wireName}' is ${severity.code} "
              'here and ${out.value} in the library',
            );
          }
        } finally {
          calloc.free(name);
        }
      }
      for (final facility in RkFacility.values) {
        final name = facility.wireName.toNativeUtf8();
        try {
          if (bindings.facilityValue(name, out) != 0 ||
              out.value != facility.code) {
            problems.add(
              "facility '${facility.wireName}' is ${facility.code} "
              'here and ${out.value} in the library',
            );
          }
        } finally {
          calloc.free(name);
        }
      }
    } finally {
      calloc.free(out);
    }
    return problems;
  }

  /// Provokes a panic behind the boundary, to prove for yourself that one
  /// comes back as [RkSyslogStatus.panicked] rather than taking the process
  /// with it (И144).
  static RkSyslogResult<void> provokePanicForTesting({String? libraryPath}) {
    final library = openRkSyslogLibrary(explicitPath: libraryPath);
    if (library == null) {
      return const RkSyslogFailure(
        RkSyslogStatus.unrecognised,
        'the native library is not loaded',
      );
    }
    final bindings = RkSyslogBindings(library);
    return _call(bindings, bindings.provokePanic);
  }
}

// --------------------------------------------------------------- plumbing

List<String> _names(RkSyslogBindings bindings, String kind) {
  final kindPointer = kind.toNativeUtf8();
  try {
    final out = <String>[];
    for (var index = 0; ; index++) {
      final pointer = bindings.nameAt(kindPointer, index);
      if (pointer == nullptr) break;
      out.add(pointer.toDartString());
      if (index > 4096) break; // a library that never ends is a broken one
    }
    return out;
  } finally {
    calloc.free(kindPointer);
  }
}

/// Runs a native call that reports through an out-parameter, and turns its
/// code and detail into a result.
///
/// The detail string is allocated by the native side and freed by the native
/// side (И146) — this function is the only place that happens, so there is
/// one rule and one place to check it.
RkSyslogResult<void> _call(
  RkSyslogBindings bindings,
  int Function(Pointer<Pointer<Utf8>>) body,
) {
  final error = calloc<Pointer<Utf8>>();
  try {
    final code = body(error);
    if (code == 0) return const RkSyslogOk(null);
    final namePointer = bindings.statusName(code);
    final status = RkSyslogStatus.fromName(
      namePointer == nullptr ? null : namePointer.toDartString(),
    );
    var detail = '';
    if (error.value != nullptr) {
      detail = error.value.toDartString();
      bindings.stringFree(error.value);
      error.value = nullptr;
    }
    if (status == RkSyslogStatus.unrecognised) {
      detail = detail.isEmpty
          ? 'the library returned status $code, which this package has no '
                'name for; it is newer than this binding'
          : '$detail (library status $code, unknown to this binding)';
    }
    return RkSyslogFailure(status, detail);
  } finally {
    calloc.free(error);
  }
}

/// Converts strings to native memory for the duration of one call, then frees
/// them. A null entry becomes `nullptr`, which every entry point reads as
/// "absent".
///
/// The native side copies whatever it keeps, so freeing here is correct and
/// necessary: nothing on the other side outlives the call.
int _withStrings(List<String?> values, int Function(List<Pointer<Utf8>>) body) {
  final pointers = <Pointer<Utf8>>[];
  try {
    for (final value in values) {
      pointers.add(value == null ? nullptr : value.toNativeUtf8());
    }
    return body(pointers);
  } finally {
    for (final pointer in pointers) {
      if (pointer != nullptr) calloc.free(pointer);
    }
  }
}
