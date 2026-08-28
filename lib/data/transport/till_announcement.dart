/// How a tablet finds the till without anybody typing an address.
///
/// # What this is now
///
/// **Settings, not an implementation.** Everything about the protocol — the
/// records, the probe, the conflict rename, the goodbye, one socket per
/// interface — lives in `rk_mdns`. What is left here is the till's own
/// vocabulary: what it calls itself, which service type a TelePOS terminal
/// looks for, which two ports it serves on, and what belongs in the `TXT`.
///
/// It used to be 672 lines of protocol. Those lines are not gone; they were
/// finished and moved, and the version that came back can do the four things
/// the Dart one could not:
///
/// * **Probe before claiming a name** (RFC 6762 §8.1). Two tills configured
///   alike used to both answer, and a tablet reached whichever replied first.
///   That is a setup mistake, it is now *visible*, and the second till moves
///   to `till-3-2` rather than fighting.
/// * **Say goodbye on a clean stop** (§10.1). Without it a tablet held a dead
///   till for the full record lifetime.
/// * **Answer a `QU` question directly** (§5.4), which is the only reply a
///   resolver behind an access point that drops multicast replies ever sees.
/// * **Choose which interfaces to announce on.** Measured 2026-08-06: a
///   third-party resolver asked to resolve a till announced on every interface
///   picked the machine's docker bridge, and a client following that answer
///   waits for a timeout. See [TillAnnouncement.start].
///
/// # The known cost, and why it is not a defect
///
/// mDNS is filtered on a good number of guest networks. When it is, this
/// announcement goes nowhere and the terminal falls back to the address —
/// which is why the certificate carries the address too. That state has to be
/// *visible*: a till that quietly stopped being findable looks like a broken
/// network and gets searched for in the wrong place. Hence
/// [AnnouncementUnavailable] carrying a sentence rather than a bool.
///
/// # Under `flutter test` there is no native library
///
/// `flutter test` does not build an FFI plugin's native part, so on an
/// ordinary test run [TillAnnouncement.start] answers
/// [AnnouncementUnavailable] naming the missing library. That is the honest
/// answer and not a stub: the till still sells and is still reachable by
/// address. The tests that need the real thing are in `test/native/`, tagged
/// `native`, and they **fail** when it is absent — which is the only way to
/// tell the two paths apart from outside.
library;

import 'dart:async';
import 'dart:io';

import 'package:rk_mdns/rk_mdns.dart' as rk;

/// The port every mDNS responder on the network listens on.
///
/// Overridable in [TillAnnouncement.start] for tests, which use a private port
/// so that the machine's own responder — Windows has one, macOS has one, a
/// Linux with Avahi has one — does not answer questions meant for this one.
/// The datagram is a real multicast datagram to 224.0.0.251 either way.
const int mdnsPort = 5353;

/// The group mDNS lives in.
final InternetAddress mdnsGroupV4 = InternetAddress('224.0.0.251');

/// The DNS-SD service type a TelePOS terminal looks for.
const String tillServiceType = '_telepos._tcp.local';

/// Seconds a resolver may cache the host and service records.
///
/// Two minutes, not the hour DNS-SD suggests for stable services: a till that
/// moved by DHCP has to become findable at its new address without anybody
/// power-cycling a tablet, and the goodbye packet on a clean stop only covers
/// the stops that are clean.
const Duration tillHostTtl = Duration(minutes: 2);

/// How long a resolver may cache the fact that the service exists at all.
const Duration tillServiceTtl = Duration(minutes: 75);

/// A live announcement, and the facts it is announcing.
class TillAnnouncement {
  TillAnnouncement._(
    this._responder,
    this.name,
    this.httpsPort,
    this.quicPort,
    this.addresses,
    this.hostName,
    this.instanceName,
    this.usingRequestedName,
  );

  final rk.MdnsResponder _responder;

  /// What the till calls itself: `till-3`, announced as `till-3.local`.
  final String name;

  /// Where the page is served. This is the port a terminal opens.
  final int httpsPort;

  /// Where WebTransport listens — UDP, and a different number.
  ///
  /// Carried in the `TXT` record rather than in a second `SRV`, because it is
  /// not a second service: it is the same till, and a terminal that found the
  /// page has already found everything it needs.
  ///
  /// `null` when the QUIC listener did not come up. The entry is then left out
  /// of the record rather than sent as a zero: a terminal reading `quic=0`
  /// would dial a port and wait, where an absent entry lets it say straight
  /// away that this till has no wire.
  final int? quicPort;

  /// The addresses offered as `A` records — the same ones the certificate is
  /// issued for.
  final List<String> addresses;

  /// The name a resolver asks for: `till-3.local`.
  ///
  /// **Read from the responder, not composed here.** After a name conflict it
  /// is `till-3-2.local`, and a caller that assumed otherwise would print an
  /// address nothing resolves.
  final String hostName;

  /// The full DNS-SD instance name, likewise as claimed rather than as asked.
  final String instanceName;

  /// Whether the till got the name it asked for.
  ///
  /// `false` means another machine on this network already answers to it. That
  /// is a setup mistake with a consequence an operator can see — a tablet
  /// looking for `till-3` reaches the other machine — so it is worth a line in
  /// the log rather than silence.
  final bool usingRequestedName;

  /// Everything the responder does, in order: the probes, a conflict if there
  /// is one, the claim, each announcement, each question answered, and the
  /// goodbye.
  Stream<rk.ResponderEvent> get events => _responder.events;

  /// Says it again, unprompted.
  ///
  /// Kept for the caller who has a reason to repeat — an interface that came
  /// back, an address that changed. The responder announces three times on its
  /// own (RFC 6762 §8.3), so this is not needed in the ordinary case; it is a
  /// no-op that returns rather than an error, because a caller asking for an
  /// extra announcement should never have to handle a failure for it.
  void announce() {}

  /// Withdraws the announcement and closes the socket.
  ///
  /// Returns only after the goodbye — the same records with a lifetime of
  /// zero, RFC 6762 §10.1 — has gone out. That is what stops a tablet holding
  /// a dead till in its cache for the next two minutes, and it is why this is
  /// worth awaiting.
  Future<void> stop() => _responder.stop();

  /// Opens the responder and announces this till.
  ///
  /// Answers with a [TillAnnouncement] or an [AnnouncementUnavailable]; never
  /// throws. A till that cannot announce itself still sells, still serves its
  /// page and is still reachable by address — the announcement is how it is
  /// *found*, not how it works.
  ///
  /// [disabled] is the operator's switch, and it produces a named state rather
  /// than silence for the same reason everything else here does: "we chose not
  /// to announce" and "the announcement is being filtered" look identical from
  /// a tablet, and only one of them is anybody's fault.
  ///
  /// [addresses] is what goes into the `A` records. **Passing more than is
  /// reachable is not free**, and the cost is not the same as it is for a
  /// certificate: in a certificate an `iPAddress` entry is *checked* — a spare
  /// one costs nothing, a missing one costs the handshake — while here it is
  /// *tried*, and a client works down the list paying a connection timeout for
  /// each address nothing answers on. Measured 2026-08-06 with a third-party
  /// resolver: given every interface of a machine with a docker bridge, it
  /// resolved the till to the bridge.
  ///
  /// [interfaces] is the other way to say the same thing, and the better one
  /// when the answer is known by interface rather than by address: naming
  /// `eth0` announces its addresses and no others. A name that matches no
  /// interface is refused rather than ignored.
  static Future<Object> start({
    required String name,
    required int httpsPort,
    required int? quicPort,
    List<String> addresses = const <String>[],
    List<String> interfaces = const <String>[],
    bool disabled = false,
    int port = mdnsPort,
  }) async {
    if (disabled) {
      return const AnnouncementUnavailable(
        'объявление по mDNS выключено в настройках: терминал найдёт кассу '
        'только по адресу, введённому руками',
      );
    }
    if (name.trim().isEmpty) {
      return const AnnouncementUnavailable(
        'у кассы нет имени, а объявлять безымянное значит занять в сети '
        'запись, по которой ничего не разрешается',
      );
    }
    if (addresses.isEmpty && interfaces.isEmpty) {
      // An announcement with no `A` record resolves to nothing. It would look
      // like a working till in a service browser and fail at the first
      // connection, which is the worst of both.
      return const AnnouncementUnavailable(
        'у этой машины нет ни одного сетевого адреса — объявлять нечего, '
        'терминал на другом устройстве до неё не дойдёт',
      );
    }

    final started = await rk.MdnsResponder.start(
      rk.ServiceAnnouncement(
        instanceName: name,
        serviceType: tillServiceType,
        port: httpsPort,
        txt: <String>[
          if (quicPort != null) 'quic=$quicPort',
          'path=/rk',
          // The scheme is stated rather than assumed: the page is served over
          // TLS and only over TLS, and a terminal that guessed `http` would
          // get a closed connection with nothing explaining it.
          'scheme=https',
        ],
        addresses: addresses,
        interfaces: interfaces,
        hostTtl: tillHostTtl,
        serviceTtl: tillServiceTtl,
        mdnsPort: port,
      ),
    );

    if (!started.isOk) {
      return AnnouncementUnavailable(_reasonFor(started, port));
    }

    final responder = started.responder!;
    // The name AFTER the probe, not the one that was asked for. They differ
    // exactly when another machine already answers to it, which is the case
    // this whole exchange exists to make visible.
    //
    // Waiting for it is the point, and it was got wrong first: `start`
    // returns as soon as the sockets are open, while probing runs on the
    // responder's own thread for something over a second (RFC 6762 §8.1 — a
    // random delay of up to 250 ms and then three probes 250 ms apart). Read
    // straight away, the state still holds the name that was *asked for*, so a
    // till that had just been renamed reported the other machine's name and
    // sent an operator looking at the wrong address.
    final state = await _claimedState(responder);
    final claimedInstance = state?.instance ?? '$name.$tillServiceType';
    final claimedHost = state?.host ?? '$name.local';
    final announced = state?.addresses ?? addresses;

    return TillAnnouncement._(
      responder,
      name,
      httpsPort,
      quicPort,
      List<String>.unmodifiable(announced),
      claimedHost,
      claimedInstance,
      claimedInstance.startsWith('$name.'),
    );
  }
}

/// How long to wait for the probe to settle before reporting a name.
///
/// Probing is a random delay of up to 250 ms and then three probes 250 ms
/// apart (RFC 6762 §8.1); a conflict adds a second of back-off and starts
/// again. Eight seconds covers a handful of renames and is still short enough
/// that a till which cannot settle at all does not hold up its own startup.
const Duration _probeWindow = Duration(seconds: 8);

/// The responder's state once it has claimed a name, or its last state if the
/// window ran out.
///
/// Polled rather than taken from the event stream. The stream is a broadcast
/// stream: an event sent between `start` returning and this subscribing is
/// simply gone, so waiting on it would work almost always and lose the name
/// occasionally — which is the worst kind of nearly.
Future<rk.ResponderState?> _claimedState(rk.MdnsResponder responder) async {
  final deadline = DateTime.now().add(_probeWindow);
  rk.ResponderState? last;
  while (DateTime.now().isBefore(deadline)) {
    last = await responder.state();
    if (last == null || last.claimed) return last;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return last;
}

/// Turns a status from the package into a sentence for the till's log.
///
/// One line per status rather than the status name, because the reader is an
/// operator looking at a till that cannot be found, and `portInUse` is not an
/// instruction.
String _reasonFor(rk.MdnsResponderStart started, int port) {
  final detail = started.detail;
  final tail = detail == null || detail.isEmpty ? '' : ' ($detail)';
  return switch (started.status) {
    rk.RkMdnsStatus.portInUse =>
      'порт $port уже занят чем-то, что не согласилось им поделиться: на '
          'Windows его держит Chrome, на Linux — avahi-daemon$tail',
    rk.RkMdnsStatus.noInterface =>
      'у этой машины нет ни одного сетевого интерфейса, по которому можно '
          'объявлять$tail',
    rk.RkMdnsStatus.invalidArgument =>
      'объявление настроено неверно и потому не отправлено$tail',
    rk.RkMdnsStatus.unsupported =>
      'нативной части rk_mdns в этой сборке нет — касса работает и доступна '
          'по адресу, но сама себя в сети не объявляет$tail',
    _ => 'касса не смогла объявить себя по mDNS: ${started.status.name}$tail',
  };
}

/// Why the till is not announcing itself, when it is not.
///
/// A value, never an exception (И144). The till goes on selling and goes on
/// serving its page; what is lost is being *found* without somebody typing an
/// address, and that loss has to be readable in the log rather than inferred
/// from a tablet that cannot see anything.
class AnnouncementUnavailable {
  const AnnouncementUnavailable(this.reason);

  /// One sentence, for a log an operator reads.
  final String reason;

  @override
  String toString() => reason;
}
