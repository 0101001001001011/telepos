/// Sending a sale from a till to the shop server, with an acknowledgement that
/// means "on disk".
///
/// To run it (needs `rust/` built and a server running):
///
/// ```bash
/// cd rust && cargo build --release && cd ..
/// nats-server -c sync_always.conf     # see below
/// dart run example/rk_nats_example.dart
/// ```
///
/// `sync_always.conf`:
///
/// ```text
/// port: 4222
/// http_port: 8222
/// jetstream {
///   store_dir: "./store"
///   sync_interval: "always"
/// }
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:rk_nats/rk_nats.dart';

/// Fetches the monitoring document. The library deliberately does not: this
/// keeps an HTTP stack out of the native side, and leaves the proof as
/// something you can print and attach to a ticket.
Future<String> fetchVarz(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

Future<void> main() async {
  final libraryPath = 'rust/target/release/${rkNatsDefaultLibraryFileName()}';

  // No policy given, so it is fsyncOnAck. A weaker one would have had to be
  // named right here, in the source, where a reviewer sees it.
  final connected = await RkNatsClient.connect(
    RkNatsConnectOptions(
      servers: ['nats://127.0.0.1:4222'],
      name: 'till-17',
      evidence: RkNatsVarzEvidence(
        await fetchVarz('http://127.0.0.1:8222/varz'),
      ),
    ),
    libraryPath: libraryPath,
  );

  if (!connected.isOk) {
    stderr.writeln('did not connect: ${connected.code} ${connected.message}');
    exitCode = 1;
    return;
  }

  final client = connected.value!;
  print(
    'server ${client.durability.server?.version}, '
    'an acknowledgement means ${client.ackMeaning.name}',
  );

  if (!client.satisfiesPolicy) {
    // Not a crash — a conversation with operations: the server was started
    // without sync_interval: "always", and an acknowledgement here means less
    // than the till asked for.
    stderr.writeln('server does not satisfy policy ${client.policy.name}');
    await client.close();
    exitCode = 2;
    return;
  }

  final stream = await client.ensureStream(
    const RkNatsStreamOptions(
      name: 'sales',
      subjects: ['sales.>'],
      duplicateWindow: Duration(minutes: 10),
    ),
  );
  if (!stream.isOk) {
    stderr.writeln('stream: ${stream.code} ${stream.message}');
    await client.close();
    exitCode = 3;
    return;
  }

  // The receipt number as the message id: a repeat after a dropped link is
  // recognised by the server and does not become a second sale.
  final ack = await client.publish(
    stream: 'sales',
    subject: 'sales.till17',
    payload: utf8.encode('{"receipt":"000017","total":"1250.000"}'),
    messageId: 'till17-000017',
  );

  if (!ack.isOk) {
    stderr.writeln('the sale did not leave: ${ack.code} ${ack.message}');
    await client.close();
    exitCode = 4;
    return;
  }

  print(
    'sale ${ack.value!.sequence}, duplicate: ${ack.value!.duplicate}, '
    'an acknowledgement means ${ack.value!.ackMeaning.name}',
  );

  // From the shop server's side: a durable consumer remembers how far it got.
  final batch = await client.fetch(stream: 'sales', consumer: 'shop-server');
  for (final message in batch.value ?? const <RkNatsMessage>[]) {
    print('received ${utf8.decode(message.payload)}');
    await client.ack(message);
  }

  await client.close();
}
