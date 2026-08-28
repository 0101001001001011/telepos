/// The whole chain, end to end, when the native library has been built.
///
/// Skipped when it has not: the per-platform build wiring is decided
/// elsewhere, and this package must not pretend to have it. Build it with
///
///     cargo build --manifest-path rust/Cargo.toml
///
/// and this file runs against the result.
library;

import 'dart:io';

import 'package:rk_pki/rk_pki.dart';
import 'package:test/test.dart';

/// Where `cargo build` leaves the shared library on each platform.
String? findNativeLibrary() {
  final names = <String>[
    if (Platform.isWindows) 'rk_pki.dll',
    if (Platform.isMacOS) 'librk_pki.dylib',
    if (!Platform.isWindows && !Platform.isMacOS) 'librk_pki.so',
  ];
  for (final profile in <String>['debug', 'release']) {
    for (final name in names) {
      final path = 'rust/target/$profile/$name';
      if (File(path).existsSync()) return File(path).absolute.path;
    }
  }
  return null;
}

void main() {
  final libraryPath = findNativeLibrary();
  final reason = libraryPath == null
      ? 'the native library has not been built; run cargo build in rust/'
      : null;

  group('over the real library', () {
    late Directory store;

    setUp(() {
      store = Directory.systemTemp.createTempSync('rk_pki_dart_test');
    });

    tearDown(() {
      if (store.existsSync()) store.deleteSync(recursive: true);
    });

    Future<RkPki> openTill() async {
      final opened = await RkPki.open(
        config: PkiConfig(
          storeDirectory: store.path,
          installationId: 'inst-1',
          machineId: 'till-17',
          machineKind: MachineKind.till,
        ),
        libraryPath: libraryPath,
      );
      expect(opened.errorOrNull, isNull, reason: '${opened.errorOrNull}');
      return opened.valueOrNull!;
    }

    test('the probe finds it and reports its version', () {
      final probe = RkPki.probe(libraryPath: libraryPath);
      expect(probe.isOk, isTrue, reason: '${probe.errorOrNull}');
      expect(probe.valueOrNull, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('a till is its own authority and enrols itself', () async {
      final pki = await openTill();
      addTearDown(pki.close);

      final root = await pki.initialiseAuthority();
      expect(root.errorOrNull, isNull, reason: '${root.errorOrNull}');
      expect(root.valueOrNull!.isCa, isTrue);

      final invite = await pki.createInvite();
      expect(invite.valueOrNull!.code, isNotEmpty);

      final enrolled = await pki.enroll(
        invite: invite.valueOrNull!.code,
        profile: CertProfile.machine,
      );
      expect(enrolled.errorOrNull, isNull, reason: '${enrolled.errorOrNull}');
      final info = enrolled.valueOrNull!;
      expect(info.subjectMachineId, 'till-17');
      expect(info.installationId, 'inst-1');
      expect(info.machineKind, MachineKind.till);
      expect(info.profile, CertProfile.machine);
      expect(info.fingerprintSha256.length, 64);
      expect(
        info.notAfter.difference(info.notBefore).inDays,
        greaterThanOrEqualTo(29),
      );
    });

    test('an invite works once', () async {
      final pki = await openTill();
      addTearDown(pki.close);
      await pki.initialiseAuthority();
      final invite = (await pki.createInvite()).valueOrNull!;
      await pki.enroll(invite: invite.code, profile: CertProfile.machine);

      final second = await pki.enroll(
        invite: invite.code,
        profile: CertProfile.machine,
      );
      expect(second.errorOrNull, isA<InviteInvalid>());
      expect(second.errorOrNull!.degradesLikeOffline, isFalse);
    });

    test('an expired certificate degrades like an absent network', () async {
      final pki = await openTill();
      addTearDown(pki.close);
      await pki.initialiseAuthority();
      final invite = (await pki.createInvite()).valueOrNull!;
      await pki.enroll(invite: invite.code, profile: CertProfile.machine);

      final later = DateTime.now().toUtc().add(const Duration(days: 31));
      final current = await pki.current(CertProfile.machine, now: later);
      expect(current.errorOrNull, isA<CertificateExpired>());
      expect(current.errorOrNull!.degradesLikeOffline, isTrue);
      expect(current.errorOrNull!.stopsSelling, isFalse);
      expect(current.errorOrNull!.tearsDownOpenSessions, isFalse);

      final status = await pki.status(CertProfile.machine, now: later);
      expect(status.valueOrNull!.expired, isTrue);
      expect(status.valueOrNull!.present, isTrue);
      expect(status.valueOrNull!.blocksNewSessions, isTrue);
      expect(status.valueOrNull!.tearsDownOpenSessions, isFalse);
      expect(status.valueOrNull!.stopsSelling, isFalse);
    });

    test('a certificate from another installation is refused', () async {
      final ours = await openTill();
      addTearDown(ours.close);
      await ours.initialiseAuthority();
      final invite = (await ours.createInvite()).valueOrNull!;
      await ours.enroll(invite: invite.code, profile: CertProfile.machine);

      final otherStore = Directory.systemTemp.createTempSync('rk_pki_other');
      addTearDown(() => otherStore.deleteSync(recursive: true));
      final theirs = (await RkPki.open(
        config: PkiConfig(
          storeDirectory: otherStore.path,
          installationId: 'inst-2',
          machineId: 'till-17',
          machineKind: MachineKind.till,
        ),
        libraryPath: libraryPath,
      )).valueOrNull!;
      addTearDown(theirs.close);
      await theirs.initialiseAuthority();
      final theirInvite = (await theirs.createInvite()).valueOrNull!;
      await theirs.enroll(
        invite: theirInvite.code,
        profile: CertProfile.machine,
      );
      final theirLeaf = (await theirs.exportCertificate(
        CertProfile.machine,
      )).valueOrNull!;

      final verdict = await ours.verifyPeer(theirLeaf);
      expect(verdict.errorOrNull, isA<CertificateRejected>());
      expect(verdict.errorOrNull!.degradesLikeOffline, isFalse);
      expect(verdict.errorOrNull!.isSecurityEvent, isTrue);

      // The control: our own certificate through the same call.
      final ourLeaf = (await ours.exportCertificate(
        CertProfile.machine,
      )).valueOrNull!;
      final ourVerdict = await ours.verifyPeer(ourLeaf);
      expect(ourVerdict.isOk, isTrue, reason: '${ourVerdict.errorOrNull}');
    });

    test('rotation needs no invite and no human', () async {
      final pki = await openTill();
      addTearDown(pki.close);
      await pki.initialiseAuthority();
      final invite = (await pki.createInvite()).valueOrNull!;
      final first = (await pki.enroll(
        invite: invite.code,
        profile: CertProfile.machine,
      )).valueOrNull!;

      final at = DateTime.now().toUtc().add(const Duration(days: 21));
      final rotated = await pki.rotate(CertProfile.machine, now: at);
      expect(rotated.errorOrNull, isNull, reason: '${rotated.errorOrNull}');
      expect(
        rotated.valueOrNull!.fingerprintSha256,
        isNot(first.fingerprintSha256),
      );
    });

    test('an unknown operation name comes back as a value', () async {
      // The boundary refuses what it does not know rather than crashing, and
      // a name is the only thing it will accept.
      final pki = await openTill();
      addTearDown(pki.close);
      final result = await pki.current(CertProfile.machine);
      expect(result.errorOrNull, isA<CertificateNotFound>());
      expect(result.errorOrNull!.degradesLikeOffline, isTrue);
    });

    test('argon2 hashing goes through the boundary and back', () async {
      final hashed = await secretHash('1234', libraryPath: libraryPath);
      expect(hashed.errorOrNull, isNull, reason: '${hashed.errorOrNull}');
      expect(hashed.valueOrNull, startsWith(r'$argon2id$'));

      expect(
        (await secretVerify(
          '1234',
          hashed.valueOrNull!,
          libraryPath: libraryPath,
        )).valueOrNull,
        isTrue,
      );
      expect(
        (await secretVerify(
          '1235',
          hashed.valueOrNull!,
          libraryPath: libraryPath,
        )).valueOrNull,
        isFalse,
      );

      // The defect being replaced: two people with the same PIN used to have
      // byte-identical stored values.
      final again = await secretHash('1234', libraryPath: libraryPath);
      expect(again.valueOrNull, isNot(hashed.valueOrNull));
    });

    test('a closed store answers rather than hangs', () async {
      final pki = await openTill();
      await pki.close();
      await pki.close(); // idempotent
      final result = await pki.current(CertProfile.machine);
      expect(result.errorOrNull, isA<NativeFault>());
    });

    group('over the real library the alternative names', () {
      test('carry the name and the address through to the leaf', () async {
        // The two halves of how a terminal finds this till: the name over
        // mDNS, the address for the networks where mDNS is filtered. A leaf
        // missing the address is a leaf whose fallback fails the handshake.
        final pki = await openTill();
        addTearDown(pki.close);
        await pki.initialiseAuthority();
        final invite = (await pki.createInvite()).valueOrNull!;

        final enrolled = await pki.enroll(
          invite: invite.code,
          profile: CertProfile.browserFacing,
          dnsNames: const ['till-17.local'],
          ipAddresses: const ['192.168.1.50'],
        );

        expect(enrolled.errorOrNull, isNull, reason: '${enrolled.errorOrNull}');
        final info = enrolled.valueOrNull!;
        expect(info.dnsNames, <String>['till-17.local']);
        expect(info.ipAddresses, <String>['192.168.1.50']);
      });

      test('refuse an address that is not one, as a value', () async {
        // Not a throw, and not a silent drop: the caller has to be able to
        // tell "issued without the address" from "issued".
        final pki = await openTill();
        addTearDown(pki.close);
        await pki.initialiseAuthority();
        final invite = (await pki.createInvite()).valueOrNull!;

        final enrolled = await pki.enroll(
          invite: invite.code,
          profile: CertProfile.browserFacing,
          ipAddresses: const ['not-an-address'],
        );

        expect(enrolled.valueOrNull, isNull);
        expect(enrolled.errorOrNull, isA<BadRequest>());
      });

      test('survive rotation, which is where DHCP shows up', () async {
        // Rotation is where a changed address has to land: renewal happens
        // without a human, and a leaf that quietly kept yesterday's address
        // would name a machine that is no longer at it.
        final pki = await openTill();
        addTearDown(pki.close);
        await pki.initialiseAuthority();
        final invite = (await pki.createInvite()).valueOrNull!;
        await pki.enroll(
          invite: invite.code,
          profile: CertProfile.browserFacing,
          dnsNames: const ['till-17.local'],
          ipAddresses: const ['192.168.1.50'],
        );

        final rotated = await pki.rotate(
          CertProfile.browserFacing,
          dnsNames: const ['till-17.local'],
          ipAddresses: const ['192.168.1.77'],
        );

        expect(rotated.errorOrNull, isNull, reason: '${rotated.errorOrNull}');
        expect(rotated.valueOrNull!.ipAddresses, <String>['192.168.1.77']);
      });
    }, skip: reason);

    group('over the real library the server credential', () {
      test('hands out the browser-facing leaf with a usable key', () async {
        final pki = await openTill();
        addTearDown(pki.close);
        await pki.initialiseAuthority();
        final invite = (await pki.createInvite()).valueOrNull!;
        await pki.enroll(
          invite: invite.code,
          profile: CertProfile.browserFacing,
          dnsNames: const ['localhost'],
        );

        final credential = await pki.serverCredential(
          CertProfile.browserFacing,
        );

        expect(
          credential.errorOrNull,
          isNull,
          reason: '${credential.errorOrNull}',
        );
        final value = credential.valueOrNull!;
        expect(
          value.chainPem,
          contains('BEGIN CERTIFICATE'),
          reason: 'QuicServerConfig.certificateChainPem takes it as-is',
        );
        expect(
          value.privateKeyPem,
          contains('BEGIN PRIVATE KEY'),
          reason: 'QuicServerConfig.privateKeyPem wants PKCS#8, and the point '
              'of this call is that no reformatting sits between them',
        );
      });

      test('refuses the machine identity, as a value', () async {
        final pki = await openTill();
        addTearDown(pki.close);
        await pki.initialiseAuthority();
        final invite = (await pki.createInvite()).valueOrNull!;
        await pki.enroll(invite: invite.code, profile: CertProfile.machine);

        final credential = await pki.serverCredential(CertProfile.machine);

        expect(
          credential.errorOrNull,
          isNotNull,
          reason: 'the key mutual TLS rests on must not come out here',
        );
        expect(credential.valueOrNull, isNull);
      });

      test('does not print the key when it prints itself', () async {
        final pki = await openTill();
        addTearDown(pki.close);
        await pki.initialiseAuthority();
        final invite = (await pki.createInvite()).valueOrNull!;
        await pki.enroll(
          invite: invite.code,
          profile: CertProfile.browserFacing,
          dnsNames: const ['localhost'],
        );

        final value =
            (await pki.serverCredential(CertProfile.browserFacing))
                .valueOrNull!;

        // A credential that logged itself would hand the key to every log
        // shipper on the machine, which is a wider grant than the one this
        // export was given.
        expect(value.toString(), isNot(contains('PRIVATE KEY')));
        expect(value.toString(), contains('key withheld'));
      });
    });
  }, skip: reason);
}
