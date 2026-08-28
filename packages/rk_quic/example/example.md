# Example

The till brings up an endpoint and tells the browser about a change of state by
itself — waiting for nothing from it.

```dart
import 'package:rk_quic/rk_quic.dart';

Future<void> main() async {
  // The version comes from the loaded library, not from a Dart constant:
  // if a stale artefact is sitting next to you, this is where it shows.
  print('rk_quic ${rkQuicVersion ?? "no native part"}');

  final start = await QuicServer.start(QuicServerConfig(
    bindAddress: '0.0.0.0:4433',
    // Issued by rk_pki. This package deliberately does not mint
    // certificates: two certificate authorities in one installation is an
    // installation where nobody chose between them.
    certificateChainPem: chainPem,
    privateKeyPem: keyPem, // PKCS#8
  ));

  final server = start.server;
  if (server == null) {
    // portInUse, badCertificate, invalidArgument, unsupported — a value,
    // not an exception. The till carries on selling, the browser
    // carries on polling REST.
    print('the endpoint did not come up: $start');
    return;
  }
  print('listening on port ${server.port}');

  server.events.listen((event) {
    switch (event) {
      case SessionOpened(:final sessionId):
        // Nobody asked for anything. That is the entire point of the package.
        server.send(sessionId, 'print job 41 printed');
      case SessionClosed(:final sessionId, :final reason):
        // Browser closed, laptop lid shut, Wi-Fi gone — from the till's point
        // of view these are the same thing: there is nowhere left to write.
        print('session $sessionId is gone: $reason');
      case StreamMessageReceived(:final message):
        print('from the browser: $message');
      case DatagramReceived(:final message):
        print('datagram: $message');
      case EndpointError(:final message):
        print('the endpoint is unwell: $message');
      case UnknownQuicEvent(:final kind):
        // An event from a newer library. Kept whole, rather than dropped or
        // forced into the nearest known case.
        print('unfamiliar event: $kind');
    }
  });

  await Future<void>.delayed(const Duration(minutes: 5));
  await server.stop();
}
```
