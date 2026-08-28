/// What happens when the native library is not there.
///
/// This is the state every consumer is in before the per-platform build
/// wiring lands, and the state a broken deployment is in afterwards. Nothing
/// may throw, nothing may hang, and nothing may claim a machine is trusted.
library;

import 'package:rk_pki/rk_pki.dart';
import 'package:test/test.dart';

const _absent = 'a-library-that-is-not-here';

void main() {
  test('the probe is honest rather than optimistic', () {
    final probe = RkPki.probe(libraryPath: _absent);
    expect(probe.isOk, isFalse);
    expect(probe.errorOrNull, isA<NativeUnavailable>());
    expect(probe.errorOrNull!.stopsSelling, isFalse);
  });

  test('hasNativeCrypto answers without throwing', () {
    // On a machine where the library has been built and is on the search
    // path this is true; where it has not, false. Either way it is a probe
    // that returns, which is the property under test.
    expect(hasNativeCrypto, isA<bool>());
  });

  test('opening a store reports the absence as a value', () async {
    final opened = await RkPki.open(
      config: const PkiConfig(
        storeDirectory: '.dart_tool/rk_pki_test_store',
        installationId: 'inst-1',
        machineId: 'till-17',
        machineKind: MachineKind.till,
      ),
      libraryPath: _absent,
    );
    expect(opened.isOk, isFalse);
    expect(opened.errorOrNull, isA<NativeUnavailable>());
  });

  test('a bad configuration is caught before any isolate is started', () async {
    final opened = await RkPki.open(
      config: const PkiConfig(
        storeDirectory: '.dart_tool/rk_pki_test_store',
        installationId: 'inst:1',
        machineId: 'till-17',
        machineKind: MachineKind.till,
      ),
      libraryPath: _absent,
    );
    expect(opened.errorOrNull, isA<BadRequest>());
  });

  test('hashing a secret without a library is a value, not a throw', () async {
    final hashed = await secretHash('1234', libraryPath: _absent);
    expect(hashed.isOk, isFalse);
    expect(hashed.errorOrNull, isA<NativeUnavailable>());

    final verified = await secretVerify(
      '1234',
      r'$argon2id$v=19$m=19456,t=2,p=1$c2FsdA$aGFzaA',
      libraryPath: _absent,
    );
    expect(verified.isOk, isFalse);
    expect(verified.errorOrNull, isA<NativeUnavailable>());
  });

  test('the ABI this binding speaks is pinned', () {
    // A library reporting anything else is refused rather than called; the
    // constant is here so that a change to it is a visible, deliberate act.
    expect(rkPkiAbiVersion, 1);
  });
}
