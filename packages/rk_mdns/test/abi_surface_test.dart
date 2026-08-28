@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_mdns/rk_mdns.dart';

import 'support/built_library.dart';

/// Three files describe the same boundary — `src/rk_mdns.h`, `rust/src/`, and
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
    '${packageRoot()}/src/rk_mdns.h',
  ).readAsStringSync();
  late final String statusRs = File(
    '${packageRoot()}/rust/src/status.rs',
  ).readAsStringSync();
  late final String loaderDart = File(
    '${packageRoot()}/lib/src/loader_io.dart',
  ).readAsStringSync();

  group('the header and the Dart bindings name the same symbols', () {
    test('every function the header declares is looked up somewhere', () {
      final declared = RegExp(
        r'\b(rk_mdns_[a-z_]+)\s*\(',
        multiLine: true,
      ).allMatches(header).map((m) => m.group(1)!).toSet();

      expect(declared, isNotEmpty, reason: 'the header parse found nothing');
      expect(
        declared,
        containsAll(<String>{
          'rk_mdns_abi_version',
          'rk_mdns_version',
          'rk_mdns_string_free',
          'rk_mdns_last_error',
          'rk_mdns_responder_start',
          'rk_mdns_responder_stop',
          'rk_mdns_responder_state',
          'rk_mdns_responder_poll',
          'rk_mdns_browser_start',
          'rk_mdns_browser_stop',
          'rk_mdns_browser_poll',
          'rk_mdns_resolve_host',
          'rk_mdns_interfaces',
        }),
      );

      // And the Dart bindings must look every one of them up. This is the
      // direction that actually drifts: a function is added to the header and
      // to Rust, and the Dart side is remembered a week later.
      final bindings = File(
        '${packageRoot()}/lib/src/bindings_io.dart',
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
      final rustSources = Directory('${packageRoot()}/rust/src')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      for (final symbol in declared) {
        expect(
          rustSources,
          contains('fn $symbol('),
          reason:
              '$symbol is declared in src/rk_mdns.h but not exported '
              'from rust/src/',
        );
      }
    });

    test('the ABI generation is the same number in all three places', () {
      final inHeader = RegExp(
        r'#define RK_MDNS_ABI_VERSION\s+(\d+)',
      ).firstMatch(header);
      expect(inHeader, isNotNull, reason: 'no RK_MDNS_ABI_VERSION in header');

      final ffiRs = File('${packageRoot()}/rust/src/ffi.rs').readAsStringSync();
      final inRust = RegExp(
        r'RK_MDNS_ABI_VERSION:\s*u32\s*=\s*(\d+)',
      ).firstMatch(ffiRs);
      expect(inRust, isNotNull, reason: 'no RK_MDNS_ABI_VERSION in ffi.rs');

      final inDart = RegExp(
        r'rkMdnsAbiVersion\s*=\s*(\d+)',
      ).firstMatch(loaderDart);
      expect(
        inDart,
        isNotNull,
        reason: 'no rkMdnsAbiVersion in loader_io.dart',
      );

      expect(int.parse(inHeader!.group(1)!), rkMdnsAbiVersion);
      expect(int.parse(inRust!.group(1)!), rkMdnsAbiVersion);
      expect(int.parse(inDart!.group(1)!), rkMdnsAbiVersion);
    });

    test('the library actually exports what the header promises', () {
      final path = requireBuiltLibrary(locateBuiltLibrary());
      // `probeNativeLibrary` reports `symbolMissing` rather than `loaded` when
      // a lookup fails, so a clean `loaded` is the assertion.
      final probe = probeNativeLibrary(candidatePaths: [path]);
      expect(probe.outcome, NativeLoadOutcome.loaded, reason: probe.toString());
    });

    test('the version travels from Cargo.toml through Rust into Dart', () {
      // Not two Dart constants compared with each other: that passes when both
      // are wrong. This one reads the crate manifest and the loaded library.
      final path = requireBuiltLibrary(locateBuiltLibrary());
      final probe = probeNativeLibrary(candidatePaths: [path]);
      expect(probe.version, crateVersionFromCargoToml());
    });

    test('a library of the wrong ABI generation is refused', () {
      // The mismatch branch exercised against a REAL library rather than a
      // mock: ask for a generation that does not exist and it must be refused
      // by name.
      final path = requireBuiltLibrary(locateBuiltLibrary());
      final probe = probeNativeLibrary(
        candidatePaths: [path],
        expectedAbiVersion: rkMdnsAbiVersion + 99,
      );
      expect(probe.outcome, NativeLoadOutcome.abiMismatch);
      expect(probe.abiVersion, rkMdnsAbiVersion);
    });

    test('a path that is not a library is missing, not a crash', () {
      final probe = probeNativeLibrary(
        candidatePaths: const ['definitely-not-a-library-42.so'],
      );
      expect(probe.outcome, NativeLoadOutcome.libraryMissing);
      expect(probe.detail, isNotNull);
    });
  });

  group('the two halves present one surface', () {
    test('every method of the responder exists on the browser half', () {
      // `responder_io.dart` and `responder_web.dart` are chosen by a
      // conditional import, so nothing type-checks one against the other: code
      // compiled for both ends would simply fail to build on whichever half
      // was forgotten. That is the drift this catches, and it is the reason the
      // browser half answers `unsupported` rather than omitting the method.
      final io = File(
        '${packageRoot()}/lib/src/responder_io.dart',
      ).readAsStringSync();
      final web = File(
        '${packageRoot()}/lib/src/responder_web.dart',
      ).readAsStringSync();

      final onNative = publicMembersOf(io);
      expect(onNative, isNotEmpty, reason: 'the parse found nothing');
      expect(
        onNative,
        containsAll(<String>{
          'start',
          'stop',
          'state',
          'events',
          'initialState',
          'hasRequestedName',
        }),
      );
      expect(
        publicMembersOf(web),
        containsAll(onNative),
        reason:
            'the two halves disagree, so a caller compiled for both ends '
            'would learn which one it got',
      );
    });

    test('every member of the browser exists on the browser half', () {
      final io = File(
        '${packageRoot()}/lib/src/browser_io.dart',
      ).readAsStringSync();
      final web = File(
        '${packageRoot()}/lib/src/browser_web.dart',
      ).readAsStringSync();

      final onNative = publicMembersOf(io);
      expect(onNative, isNotEmpty, reason: 'the parse found nothing');
      expect(
        onNative,
        containsAll(<String>{
          'start',
          'stop',
          'events',
          'resolveHost',
          'mdnsInterfaces',
        }),
      );
      expect(publicMembersOf(web), containsAll(onNative));
    });

    test('no browser-side file imports dart:ffi or dart:io (И143)', () {
      // The one property that makes `flutter build web` possible for a
      // consumer, and the one a stray import silently breaks.
      //
      // The check is on the *import directive*, not on the text: an earlier
      // version searched for the string `dart:ffi` and failed on the comment
      // in loader_web.dart that explains why the import is absent. A test that
      // cannot tell a mention from a use has to be read every time it fires.
      final forbidden = RegExp(
        r'''^\s*import\s+['"]dart:(ffi|io)['"]''',
        multiLine: true,
      );
      for (final name in const [
        'loader_web.dart',
        'responder_web.dart',
        'browser_web.dart',
        'service.dart',
        'mdns_event.dart',
        'status.dart',
        'native_probe.dart',
      ]) {
        final source = File(
          '${packageRoot()}/lib/src/$name',
        ).readAsStringSync();
        final match = forbidden.firstMatch(source);
        expect(
          match,
          isNull,
          reason:
              '$name imports dart:${match?.group(1)}, which does not exist in '
              'a browser',
        );
      }
    });

    test('the import check would fire on a real import', () {
      // The check above is a regex over source text, and a regex that matches
      // nothing passes for the wrong reason. This is the negative it needs:
      // the native halves DO import dart:ffi, so the same pattern must find
      // them.
      final forbidden = RegExp(
        r'''^\s*import\s+['"]dart:(ffi|io)['"]''',
        multiLine: true,
      );
      for (final name in const [
        'loader_io.dart',
        'bindings_io.dart',
        'worker_io.dart',
      ]) {
        final source = File(
          '${packageRoot()}/lib/src/$name',
        ).readAsStringSync();
        expect(
          forbidden.hasMatch(source),
          isTrue,
          reason:
              'the pattern found no dart:ffi/dart:io import in $name, so it '
              'would not find one in a browser-side file either',
        );
      }
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

      final dartNames = RkMdnsStatus.values.map((s) => s.name).toSet();
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
      final dartNames = RkMdnsStatus.values.map((s) => s.name).toSet();

      expect(
        dartNames.difference(rustNames),
        {RkMdnsStatus.unrecognised.name},
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
          expect(
            statusFromWireName(wire),
            RkMdnsStatus.unrecognised,
            reason: 'wire: "$wire"',
          );
        }
        // And the ones that must resolve, do.
        expect(statusFromWireName('ok'), RkMdnsStatus.ok);
        expect(statusFromWireName('portInUse'), RkMdnsStatus.portInUse);
        expect(statusFromWireName('noInterface'), RkMdnsStatus.noInterface);
        expect(statusFromWireName('panic'), RkMdnsStatus.panic);
      },
    );

    test('no status is sent as a number anywhere in the Rust ABI', () {
      final apiRs = File('${packageRoot()}/rust/src/api.rs').readAsStringSync();
      // `guard` returns a pointer; a return type of i32 or c_int would mean a
      // status had become an index again.
      expect(
        RegExp(
          r'extern "C" fn \w+\([^)]*\)\s*->\s*(i32|c_int|u8)\b',
        ).hasMatch(apiRs),
        isFalse,
        reason: 'an entry point returns an integer status — И147 says names',
      );
    });
  });
}
