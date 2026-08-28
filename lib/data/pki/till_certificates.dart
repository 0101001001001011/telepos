/// The till's own certificates, and the one this machine presents to a browser.
///
/// # Why this file is in `lib/data/`
///
/// It imports `package:rk_pki`, which imports `dart:ffi`, which does not exist
/// in a browser. Section 3а keeps native code strictly below the contract, and
/// `flutter build web -t lib/web/main_web.dart` is what enforces it: naming
/// this file from anywhere above turns that job red.
///
/// # What it is for
///
/// Exactly one thing today: handing [WebTransportCredential] to the QUIC
/// endpoint. A browser opening a WebTransport session pins the certificate by
/// hash (`serverCertificateHashes`) rather than walking a chain, and it refuses
/// any certificate valid for fourteen days or more — which is why `rk_pki`'s
/// `browserFacing` profile sits at seven, and why this has to be re-issued
/// often rather than installed once.
///
/// It is **not** the machine identity. That one — mutual TLS between till,
/// shop server and relay — never leaves the native library, and nothing here
/// asks it to (И152: certificates are issued in one place, and this is that
/// place asking, not a second one issuing).
library;

import 'dart:convert';
import 'dart:io';

import 'package:rk_pki/rk_pki.dart';

import 'package:telepos/data/pki/certificate_addresses.dart';

/// What a WebTransport listener needs, plus what the browser needs to trust it.
class WebTransportCredential {
  const WebTransportCredential({
    required this.chainPem,
    required this.privateKeyPem,
    required this.notAfter,
    required this.fingerprintSha256,
    this.dnsNames = const <String>[],
    this.ipAddresses = const <String>[],
  });

  /// Имена, которые лист действительно называет — прочитанные из выписанного
  /// сертификата, а не те, что просили выписать.
  ///
  /// Разница между «просили» и «выписано» — это ровно то место, где дефект и
  /// прячется: касса, попросившая адрес у библиотеки, которая его не умеет,
  /// получала лист без адреса и не узнавала об этом. Поэтому наружу отдаётся
  /// то, что в листе, и оно же уходит в лог на подъёме.
  final List<String> dnsNames;

  /// Адреса (`iPAddress`), которые лист называет. Читаются отдельно от
  /// [dnsNames], потому что клиент, открывающий `https://192.168.1.31/`,
  /// сверяется только с этим списком.
  final List<String> ipAddresses;

  /// The SHA-256 of the leaf, which is what the browser pins.
  ///
  /// A browser opening a WebTransport session to a certificate no public
  /// authority signed passes this in `serverCertificateHashes` and then does
  /// **not** walk the chain. So this string is the whole of the trust decision
  /// on the browser side, and it has to reach the page from the till rather
  /// than be typed by anyone.
  final String fingerprintSha256;

  /// Leaf first, PEM — the shape `QuicServerConfig` takes.
  final String chainPem;

  /// PKCS#8 PEM.
  final String privateKeyPem;

  /// When the browser will start refusing this certificate.
  ///
  /// Carried because the caller has to re-issue *before* it, not after: a
  /// session cannot be opened with an expired leaf, and a till that only
  /// noticed on expiry would be a till nobody can reach for as long as it
  /// takes someone to walk over to it.
  final DateTime notAfter;

  /// Never prints the key.
  @override
  String toString() =>
      'WebTransportCredential(expires $notAfter, key withheld)';

  /// Одной строкой: за кого этот лист ручается. Для лога подъёма — оператор,
  /// у которого не идёт рукопожатие по адресу, должен увидеть здесь свой
  /// адрес или его отсутствие, а не идти за `openssl`.
  String get subjectAltNames =>
      'DNS: ${dnsNames.isEmpty ? "нет" : dnsNames.join(", ")}; '
      'IP: ${ipAddresses.isEmpty ? "нет" : ipAddresses.join(", ")}';
}

/// Turns a leaf into the thing `HttpServer` terminates TLS with.
///
/// A value, never a throw: `SecurityContext` parses PEM eagerly and raises
/// `TlsException` on anything it dislikes, and a till whose page will not come
/// up has to say so rather than die on the way up.
///
/// Bytes rather than files on purpose. Writing the key to disk to hand it to
/// `SecurityContext` would put the one secret this package guards into a
/// temporary file, whose lifetime nobody owns.
Object pageSecurityContext(WebTransportCredential leaf) {
  try {
    return SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(leaf.chainPem))
      ..usePrivateKeyBytes(utf8.encode(leaf.privateKeyPem));
  } on Object catch (error) {
    return CertificateUnavailable(
      'the browser-facing leaf was refused by the TLS layer: $error',
    );
  }
}

/// Why there is no credential, when there is none.
class CertificateUnavailable {
  const CertificateUnavailable(this.reason);

  /// A sentence for the local log. Not a code: nothing branches on it, and a
  /// till that cannot serve WebTransport goes on selling either way.
  final String reason;

  @override
  String toString() => reason;
}

/// Issues, reuses and hands over the browser-facing credential.
///
/// Every method answers with a value. A missing native library, a store that
/// cannot be written, an authority that will not initialise — none of them
/// throw, and none of them stop the till: WebTransport is how a browser
/// terminal reaches this machine, not how this machine takes money.
class TillCertificates {
  TillCertificates._(this._pki);

  final RkPki _pki;

  /// Opens the store for this installation.
  ///
  /// [storeDirectory] is created if absent. [installationId] and [machineId]
  /// identify this till inside its own installation — they are not secrets and
  /// not addresses, they are what a certificate is issued *to*.
  static Future<Object> open({
    required String storeDirectory,
    required String installationId,
    required String machineId,
  }) async {
    try {
      Directory(storeDirectory).createSync(recursive: true);
    } on Object catch (error) {
      return CertificateUnavailable(
        'the certificate store directory could not be created: $error',
      );
    }

    final opened = await RkPki.open(
      config: PkiConfig(
        storeDirectory: storeDirectory,
        installationId: installationId,
        machineId: machineId,
        machineKind: MachineKind.till,
      ),
    );

    final pki = opened.valueOrNull;
    if (pki == null) {
      return CertificateUnavailable(
        'the certificate library did not open: ${opened.errorOrNull}',
      );
    }
    return TillCertificates._(pki);
  }

  /// The credential to serve WebTransport with, issuing one if needed.
  ///
  /// Re-issues when the certificate held is missing, unreadable, or closer to
  /// expiry than [renewBefore]. Seven days of life and a two-day margin means
  /// a till that is switched on at least twice a week never presents an
  /// expired leaf; one that sits off for longer re-issues on the way up.
  ///
  /// # Второе основание для перевыпуска: имя или адрес уехали
  ///
  /// До 2026-08-05 единственным поводом был срок, и это оставляло дыру
  /// длиной в семь суток: касса, которой DHCP выдал новый адрес, держала лист
  /// со старым и отказывала в рукопожатии всем, кто приходил по новому. Теперь
  /// повод второй — [ipAddresses] или [dnsNames] содержат то, чего в
  /// удерживаемом листе нет.
  ///
  /// Условие **одностороннее**: лишнее в листе перевыпуска не вызывает. См.
  /// `addressesOutsideCertificate` — перевыпуск меняет отпечаток, приколотый
  /// каждой открытой страницей, и делать это ради вчерашнего адреса, к
  /// которому никто не придёт, значило бы ронять живые сессии за просто так.
  Future<Object> webTransportCredential({
    List<String> dnsNames = const <String>['localhost'],
    List<String> ipAddresses = const <String>[],
    Duration renewBefore = const Duration(days: 2),
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();

    final authority = await _ensureAuthority();
    if (authority != null) return authority;

    final existing = await _pki.current(CertProfile.browserFacing, now: at);
    final held = existing.valueOrNull;
    final needsIssue =
        held == null ||
        held.notAfter.difference(at) <= renewBefore ||
        addressesOutsideCertificate(
          live: ipAddresses,
          certified: held.ipAddresses,
        ).isNotEmpty ||
        namesOutsideCertificate(
          live: dnsNames,
          certified: held.dnsNames,
        ).isNotEmpty;

    if (needsIssue) {
      final issued = await _issue(
        dnsNames: dnsNames,
        ipAddresses: ipAddresses,
        hasOne: held != null,
      );
      if (issued != null) return issued;
    }

    final credential = await _pki.serverCredential(CertProfile.browserFacing);
    final value = credential.valueOrNull;
    if (value == null) {
      return CertificateUnavailable(
        'the browser-facing credential could not be read: '
        '${credential.errorOrNull}',
      );
    }

    return WebTransportCredential(
      chainPem: value.chainPem,
      privateKeyPem: value.privateKeyPem,
      notAfter: value.info.notAfter,
      fingerprintSha256: value.info.fingerprintSha256,
      // Из выписанного листа, а не из аргументов выше: если библиотека что-то
      // не положила, узнать об этом надо здесь, а не на упавшем рукопожатии.
      dnsNames: value.info.dnsNames,
      ipAddresses: value.info.ipAddresses,
    );
  }

  /// The installation's trust anchor, PEM, for handing to a device that is
  /// being paired.
  ///
  /// Public by construction: a root certificate carries no key, and the whole
  /// point of one is that everybody who should trust this installation holds a
  /// copy. What decides *who* gets a copy is not this method — it is the
  /// pairing code the till checks before serving it, and the reasoning for
  /// that lives at the serving end.
  ///
  /// A value, never a throw: an installation with no authority yet is an
  /// ordinary state on a till that has not finished setup.
  Future<Object> authorityRootPem() async {
    final root = await _pki.authorityRootPem();
    final pem = root.valueOrNull;
    if (pem == null) {
      return CertificateUnavailable(
        'this installation has no certificate authority to hand out: '
        '${root.errorOrNull}',
      );
    }
    return pem;
  }

  /// Makes this till its own authority on first run, and says nothing on every
  /// run after.
  Future<CertificateUnavailable?> _ensureAuthority() async {
    // `authorityRootPem` is the cheapest question that distinguishes "there is
    // an authority here" from "there is not" — it answers from the store and
    // touches no network.
    final info = await _pki.authorityRootPem();
    if (info.isOk) return null;

    final initialised = await _pki.initialiseAuthority();
    if (initialised.isOk) return null;
    return CertificateUnavailable(
      'this installation has no certificate authority and one could not be '
      'created: ${initialised.errorOrNull}',
    );
  }

  /// First issue uses an invite; every issue after that is a rotation, which
  /// needs no invite and no human — what authorises it is the certificate this
  /// machine already holds.
  Future<CertificateUnavailable?> _issue({
    required List<String> dnsNames,
    required List<String> ipAddresses,
    required bool hasOne,
  }) async {
    if (hasOne) {
      final rotated = await _pki.rotate(
        CertProfile.browserFacing,
        dnsNames: dnsNames,
        ipAddresses: ipAddresses,
      );
      if (rotated.isOk) return null;
      return CertificateUnavailable(
        'the browser-facing certificate could not be renewed: '
        '${rotated.errorOrNull}',
      );
    }

    final invite = await _pki.createInvite();
    final code = invite.valueOrNull?.code;
    if (code == null) {
      return CertificateUnavailable(
        'no invite could be created for the first issue: '
        '${invite.errorOrNull}',
      );
    }

    final enrolled = await _pki.enroll(
      invite: code,
      profile: CertProfile.browserFacing,
      dnsNames: dnsNames,
      ipAddresses: ipAddresses,
    );
    if (enrolled.isOk) return null;
    return CertificateUnavailable(
      'the browser-facing certificate could not be issued: '
      '${enrolled.errorOrNull}',
    );
  }

  Future<void> close() => _pki.close();
}
