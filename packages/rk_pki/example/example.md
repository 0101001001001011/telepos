# Example

A single till that is its own certificate authority: it makes a root, mints an
invite for itself, enrols, and then carries on working whatever the answers
are.

```dart
import 'package:rk_pki/rk_pki.dart';

Future<void> main() async {
  // A real probe, not a constant: it loads the library and asks its ABI
  // version. Where the native part has not been built this is false, and
  // nothing below throws.
  print('rk_pki $rkPkiVersion, native: $hasNativeCrypto');

  final opened = await RkPki.open(
    config: const PkiConfig(
      storeDirectory: '/var/lib/telepos/pki',
      installationId: 'inst-1',
      machineId: 'till-17',
      machineKind: MachineKind.till,
    ),
  );
  if (opened case PkiErr(error: final e)) {
    // Not there, or the wrong ABI. A value, not an exception — and not a
    // reason to stop selling.
    print('no PKI on this machine: $e');
    return;
  }
  final pki = (opened as PkiOk<RkPki>).value;

  // This till is the top of its installation, so it is the authority.
  await pki.initialiseAuthority();

  // The owner would read this out or scan it on another machine. Here the
  // same machine redeems it, by the same code path.
  final invite = await pki.createInvite(lifetime: const Duration(minutes: 30));
  await pki.enroll(
    invite: invite.valueOrNull!.code,
    profile: CertProfile.machine,
  );

  // And a second, shorter-lived certificate for a browser reaching this till
  // directly over WebTransport.
  //
  // The name and the address are separate lists because they become separate
  // kinds of alternative name: a browser opening `https://192.168.1.50/` reads
  // only the addresses. Both are given here because a shop is reached by name
  // where mDNS resolves and by address where it is filtered.
  final browserInvite = await pki.createInvite();
  await pki.enroll(
    invite: browserInvite.valueOrNull!.code,
    profile: CertProfile.browserFacing,
    dnsNames: <String>['till-17.local'],
    ipAddresses: <String>['192.168.1.50'],
  );

  // What still works. This call never fails, even when the certificate has
  // run out or was never issued.
  final status = (await pki.status(CertProfile.machine)).valueOrNull!;
  print(
    'expires in ${status.secondsRemaining}s, '
    'rotate at ${status.rotateAt}, '
    'selling stops: ${status.stopsSelling}', // always false
  );
  if (status.rotationDue) {
    await pki.rotate(CertProfile.machine); // no invite, no human
  }

  // Judging a peer outside a handshake — the "is this till still trusted"
  // screen. Expiry and refusal are different answers on purpose.
  switch (await pki.verifyPeer(somePeerCertificatePem)) {
    case PkiOk(value: final info):
      print('trusted: ${info.subjectMachineId}');
    case PkiErr(error: final e) when e.degradesLikeOffline:
      print('treat as offline, keep selling: $e');
    case PkiErr(error: final e):
      print('refused, and worth telling the owner: $e');
  }

  // Staff PINs. Salted Argon2id, not an RSA ciphertext comparison.
  final stored = (await secretHash('1234')).valueOrNull!;
  print('pin matches: ${(await secretVerify('1234', stored)).valueOrNull}');

  // The native handle is released here, deterministically.
  await pki.close();
}

const String somePeerCertificatePem = '-----BEGIN CERTIFICATE-----\n...';
```

## Enrolling a till from a shop server

The authority and the machine are different processes; the two calls below are
what travels between them.

```dart
// On the till: a request. The key never leaves this machine.
final csr = (await till.signingRequest(CertProfile.machine)).valueOrNull!;

// On the shop server: an invite the owner minted, and the request.
final issued = (await server.issue(
  invite: inviteCode,
  csrPem: csr.csrPem,
  machineId: 'till-17',
  machineKind: MachineKind.till,
  profile: CertProfile.machine,
)).valueOrNull!;

// Back on the till: trust the root once, then install.
await till.trustAuthority(issued.chainPem);
await till.installCertificate(
  profile: CertProfile.machine,
  certPem: issued.certPem,
  chainPem: issued.chainPem,
);
```
