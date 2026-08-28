/// The STRUCTURED-DATA field of RFC 5424.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'status.dart';

/// One `[SD-ID name="value" ...]` element.
class RkSdElement {
  RkSdElement(this.id);

  /// The SD-ID. Anything not registered with IANA must be of the form
  /// `name@enterpriseNumber` — RFC 5424 §7.2.2 — and the whole thing must fit
  /// in 32 printable ASCII bytes.
  final String id;

  final List<(String, String)> params = [];

  /// Adds a parameter.
  ///
  /// **Do not escape the value.** The native side escapes `"`, `\` and `]`
  /// exactly as RFC 5424 §6.3.3 requires; escaping here as well would put
  /// literal backslashes in the journal.
  void param(String name, String value) => params.add((name, value));
}

/// Structured data for one record.
///
/// Built as elements and parameters rather than handed over as text, so the
/// escaping is done once, in one place, by the side that also writes the
/// framing. A pre-formatted string would mean trusting every caller to have
/// escaped a stray `]`, and the failure of that trust is silent: the element
/// ends early and the rest of the record is read as free-form message.
class RkStructuredData {
  final List<RkSdElement> elements = [];

  /// Starts an element and returns it, so parameters can be added.
  RkSdElement element(String id) {
    final element = RkSdElement(id);
    elements.add(element);
    return element;
  }

  bool get isEmpty => elements.isEmpty;

  bool get isNotEmpty => elements.isNotEmpty;

  /// Hands this over to a native structured-data handle.
  ///
  /// Internal. A name or value the standard does not allow is refused here,
  /// with the offending field named — the record does not travel half-built.
  RkSyslogResult<void> writeInto(
    RkSyslogBindings bindings,
    Pointer<RkSdHandle> handle,
  ) {
    for (final element in elements) {
      final outcome = _push(bindings, (error) {
        final id = element.id.toNativeUtf8();
        try {
          return bindings.sdElement(handle, id, error);
        } finally {
          calloc.free(id);
        }
      });
      if (outcome case final RkSyslogFailure<void> failure) return failure;

      for (final (name, value) in element.params) {
        final outcome = _push(bindings, (error) {
          final namePointer = name.toNativeUtf8();
          final valuePointer = value.toNativeUtf8();
          try {
            return bindings.sdParam(handle, namePointer, valuePointer, error);
          } finally {
            calloc.free(namePointer);
            calloc.free(valuePointer);
          }
        });
        if (outcome case final RkSyslogFailure<void> failure) return failure;
      }
    }
    return const RkSyslogOk(null);
  }
}

RkSyslogResult<void> _push(
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
    return RkSyslogFailure(status, detail);
  } finally {
    calloc.free(error);
  }
}
