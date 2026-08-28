# Example

A till announces itself so a tablet can find it without anybody typing an
address, and then looks around for the other tills on the same network.

```dart
import 'package:rk_mdns/rk_mdns.dart';

Future<void> main() async {
  // The version comes from the loaded library, not from a Dart constant: if a
  // stale artefact is sitting next to you, this is where it shows.
  print('rk_mdns ${rkMdnsVersion ?? "no native part"}');

  // --- announcing -------------------------------------------------------

  final started = await MdnsResponder.start(
    const ServiceAnnouncement(
      instanceName: 'till-3',
      serviceType: '_telepos._tcp.local',
      port: 8443,
      // Everything a client needs that is not a host and a port. A
      // certificate fingerprint belongs here; a token does not — every device
      // on the link reads this.
      txt: ['quic=4433', 'path=/rk', 'scheme=https'],
    ),
  );

  if (!started.isOk) {
    // Nothing here throws. The till still sells and is still reachable by
    // address; what is lost is being *found* without somebody typing one, and
    // that is worth a line in the log rather than a crash.
    print('not announcing: ${started.status.name} — ${started.detail}');
    return;
  }
  final responder = started.responder!;

  // The name after any rename. If it is not the one that was asked for,
  // another host on this network already answers to it — a setup mistake with
  // a visible consequence, since a tablet looking for `till-3` reaches the
  // other machine.
  if (!await responder.hasRequestedName) {
    final state = await responder.state();
    print('till-3 is taken; announcing as ${state!.instance} instead');
  }

  // Watch the announcement actually leave. An interface with `sent` at zero
  // while the responder has announced means the datagram is going out one
  // door — the failure this package exists to prevent, and the only place it
  // is visible.
  responder.events.listen((event) {
    if (event is Announced) {
      print('announced on ${event.carried} of ${event.interfaces} interfaces');
    }
    if (event is NameConflict) {
      print('${event.from} was taken: ${event.detail}');
    }
  });

  // --- finding ----------------------------------------------------------

  final browsing = await MdnsBrowser.start(
    const BrowseRequest(serviceType: '_telepos._tcp.local'),
  );
  if (browsing.isOk) {
    browsing.browser!.events.listen((event) {
      switch (event) {
        case ServiceResolved(:final instance, :final addresses, :final port):
          print('$instance at ${addresses.first}:$port');
          // Null and empty are different answers: RFC 6763 §6.4 calls an entry
          // with no `=` a key that is present with no value.
          print('  quic port: ${event['quic'] ?? "none advertised"}');
        case ServiceLost(:final instance):
          print('$instance is gone');
        default:
      }
    });
  }

  // --- one name, once ---------------------------------------------------

  final found = await resolveHost(const HostQuery(hostName: 'till-4.local'));
  // An empty list is an answer, not a failure: on a network that filters
  // multicast it is the expected one, and an exception would make a filtered
  // network indistinguishable from a broken call.
  print('till-4.local -> ${found?.addresses ?? "no native part"}');

  await Future<void>.delayed(const Duration(seconds: 30));

  // Returns after the goodbye has gone out (RFC 6762 §10.1). Worth awaiting:
  // it is what stops a tablet holding this till in its cache for the next two
  // minutes.
  await browsing.browser?.stop();
  await responder.stop();
}
```
