@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';

import 'support/built_library.dart';

/// Three files describe the same boundary — `src/rk_quic.h`, `rust/src/`, and
/// the Dart bindings. Nothing makes them agree, so this suite does.
///
/// `ffigen` would have generated the Dart side from the header and removed one
/// of the three. It was not used: the surface is small enough to read in one
/// screen, ffigen needs LLVM installed wherever it is regenerated, and a
/// generated file in git invites the question of which copy is true. The drift
/// it would have prevented is caught here instead, and the check also covers
/// the Rust side, which ffigen would not have.
void main() {
  late final String header = File(
    '${_packageRoot()}/src/rk_quic.h',
  ).readAsStringSync();
  late final String statusRs = File(
    '${_packageRoot()}/rust/src/status.rs',
  ).readAsStringSync();
  late final String loaderDart = File(
    '${_packageRoot()}/lib/src/loader_io.dart',
  ).readAsStringSync();

  group('the header and the Dart bindings name the same symbols', () {
    test('every function the header declares is looked up somewhere', () {
      final declared = RegExp(
        r'\b(rk_quic_[a-z_]+)\s*\(',
        multiLine: true,
      ).allMatches(header).map((m) => m.group(1)!).toSet();

      expect(declared, isNotEmpty, reason: 'the header parse found nothing');
      expect(
        declared,
        containsAll(<String>{
          'rk_quic_abi_version',
          'rk_quic_version',
          'rk_quic_string_free',
          'rk_quic_last_error',
          'rk_quic_server_start',
          'rk_quic_server_stop',
          'rk_quic_server_local_port',
          'rk_quic_server_poll',
          'rk_quic_session_send',
          'rk_quic_stream_send',
          'rk_quic_stream_close',
        }),
      );

      // And the Dart bindings must look every one of them up. This is the
      // direction that actually drifts: a function is added to the header and
      // to Rust, and the Dart side is remembered a week later.
      final bindings = File(
        '${_packageRoot()}/lib/src/bindings_io.dart',
      ).readAsStringSync();
      for (final symbol in declared) {
        expect(
          bindings,
          contains("'$symbol'"),
          reason: '$symbol is in the header but nothing in Dart looks it up',
        );
      }

      // Every one of them must exist in Rust with #[no_mangle], or the header
      // is describing a library that does not exist.
      final rustSources = Directory('${_packageRoot()}/rust/src')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      for (final symbol in declared) {
        expect(
          rustSources,
          contains('fn $symbol('),
          reason:
              '$symbol is declared in src/rk_quic.h but not exported '
              'from rust/src/',
        );
      }
    });

    test('the ABI generation is the same number in all three places', () {
      final inHeader = RegExp(
        r'#define RK_QUIC_ABI_VERSION\s+(\d+)',
      ).firstMatch(header);
      expect(inHeader, isNotNull, reason: 'no RK_QUIC_ABI_VERSION in header');

      final ffiRs = File(
        '${_packageRoot()}/rust/src/ffi.rs',
      ).readAsStringSync();
      final inRust = RegExp(
        r'RK_QUIC_ABI_VERSION:\s*u32\s*=\s*(\d+)',
      ).firstMatch(ffiRs);
      expect(inRust, isNotNull, reason: 'no RK_QUIC_ABI_VERSION in ffi.rs');

      final inDart = RegExp(
        r'rkQuicAbiVersion\s*=\s*(\d+)',
      ).firstMatch(loaderDart);
      expect(
        inDart,
        isNotNull,
        reason: 'no rkQuicAbiVersion in loader_io.dart',
      );

      expect(int.parse(inHeader!.group(1)!), rkQuicAbiVersion);
      expect(int.parse(inRust!.group(1)!), rkQuicAbiVersion);
      expect(int.parse(inDart!.group(1)!), rkQuicAbiVersion);
    });

    test('the library actually exports what the header promises', () {
      final path = requireBuiltLibrary(locateBuiltLibrary());
      // `probeNativeLibrary` reports `symbolMissing` rather than `loaded` when
      // a lookup fails, so a clean `loaded` is the assertion.
      final probe = probeNativeLibrary(candidatePaths: [path]);
      expect(probe.outcome, NativeLoadOutcome.loaded, reason: probe.toString());
    });
  });

  group('the two halves of QuicServer present one surface', () {
    test('every method on the native half exists on the browser half', () {
      // `server_io.dart` and `server_web.dart` are chosen by a conditional
      // import, so nothing type-checks one against the other: code compiled
      // for both ends would simply fail to build on whichever half was
      // forgotten. That is the drift this catches, and it is the reason the
      // browser half answers `unsupported` rather than omitting the method.
      final io = File(
        '${_packageRoot()}/lib/src/server_io.dart',
      ).readAsStringSync();
      final web = File(
        '${_packageRoot()}/lib/src/server_web.dart',
      ).readAsStringSync();

      Set<String> answeringMethodsOf(String source) =>
          RegExp(r'Future<RkQuicStatus>\s+(\w+)\s*\(')
              .allMatches(source)
              .map((m) => m.group(1)!)
              .toSet();

      final onNative = answeringMethodsOf(io);
      expect(
        onNative,
        isNotEmpty,
        reason: 'the server_io.dart parse found nothing',
      );
      expect(
        onNative,
        containsAll(<String>{'send', 'sendOn', 'closeStream', 'stop'}),
      );
      expect(
        answeringMethodsOf(web),
        onNative,
        reason:
            'the two halves disagree, so a caller compiled for both ends '
            'would learn which one it got',
      );
    });
  });

  group('statuses cross by name (И147)', () {
    test('every Rust status name has a Dart variant of the same name', () {
      final rustNames = RegExp(
        r'Status::\w+\s*=>\s*"([a-zA-Z]+)\\0"',
      ).allMatches(statusRs).map((m) => m.group(1)!).toSet();

      expect(
        rustNames,
        isNotEmpty,
        reason: 'the status.rs parse found nothing',
      );
      expect(rustNames.length, greaterThanOrEqualTo(10));

      final dartNames = RkQuicStatus.values.map((s) => s.name).toSet();
      expect(
        dartNames,
        containsAll(rustNames),
        reason:
            'Rust can send a status name Dart has no variant for: '
            '${rustNames.difference(dartNames)}',
      );
    });

    test('the only Dart-side extra is the one that must never be sent', () {
      final rustNames = RegExp(
        r'Status::\w+\s*=>\s*"([a-zA-Z]+)\\0"',
      ).allMatches(statusRs).map((m) => m.group(1)!).toSet();
      final dartNames = RkQuicStatus.values.map((s) => s.name).toSet();

      expect(
        dartNames.difference(rustNames),
        {RkQuicStatus.unrecognised.name},
        reason:
            'a Dart variant with no Rust counterpart is dead code, except '
            'the deliberate landing place for names this build does not know',
      );
    });

    test(
      'an unknown name resolves to unrecognised, never to a wrong branch',
      () {
        for (final wire in <String?>[
          null,
          '',
          'someStatusFromANewerLibrary',
          'OK',
          '0',
          'ok ',
        ]) {
          final status = statusFromWireName(wire);
          if (wire == 'ok') {
            expect(status, RkQuicStatus.ok);
          } else {
            expect(status, RkQuicStatus.unrecognised, reason: 'wire: "$wire"');
          }
        }
        // And the one that must resolve, does.
        expect(statusFromWireName('portInUse'), RkQuicStatus.portInUse);
        expect(statusFromWireName('peerGone'), RkQuicStatus.peerGone);
        expect(statusFromWireName('panic'), RkQuicStatus.panic);
      },
    );

    test('no status is sent as a number anywhere in the Rust ABI', () {
      final ffiRs = File(
        '${_packageRoot()}/rust/src/ffi.rs',
      ).readAsStringSync();
      // `guard` returns a pointer; a return type of i32 or c_int would mean a
      // status had become an index again.
      expect(
        RegExp(
          r'extern "C" fn \w+\([^)]*\)\s*->\s*(i32|c_int|u8)\b',
        ).hasMatch(ffiRs),
        isFalse,
        reason: 'an entry point returns an integer status — И147 says names',
      );
    });
  });
}

String _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/rust').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('could not find the rk_quic package root');
}
