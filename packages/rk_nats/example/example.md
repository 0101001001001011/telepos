# Example

A sale leaves a till for the shop server, with an acknowledgement that means "on
disk". The policy is not named in the code, which is what makes it `fsyncOnAck`
— a weaker one would have had to be written down here, where a reviewer sees it.

```dart
import 'dart:convert';

import 'package:rk_nats/rk_nats.dart';

Future<void> main() async {
  final connected = await RkNatsClient.connect(
    RkNatsConnectOptions(
      servers: ['nats://127.0.0.1:4222'],
      name: 'till-17',
      // Without proof the library refuses to publish: an absent answer is a
      // refusal, not a permission.
      evidence: RkNatsVarzEvidence(
        await fetchVarz('http://127.0.0.1:8222/varz'),
      ),
    ),
    libraryPath: 'rust/target/release/${rkNatsDefaultLibraryFileName()}',
  );

  final client = connected.value!;
  print(client.ackMeaning); // RkNatsAckMeaning.fsyncedToDisk

  await client.ensureStream(
    const RkNatsStreamOptions(
      name: 'sales',
      subjects: ['sales.>'],
      duplicateWindow: Duration(minutes: 10),
    ),
  );

  // The receipt number as the message id: a repeat after a dropped link is
  // recognised by the server and does not become a second sale.
  final ack = await client.publish(
    stream: 'sales',
    subject: 'sales.till17',
    payload: utf8.encode('{"receipt":"000017","total":"1250.000"}'),
    messageId: 'till17-000017',
  );
  print('${ack.value!.sequence}, duplicate: ${ack.value!.duplicate}');

  await client.close();
}
```

`example/rk_nats_example.dart` is the runnable version, with the error handling
left in and the shop-server side — a durable consumer that remembers how far it
got — included.

```bash
cd rust && cargo build --release && cd ..
nats-server -c sync_always.conf
dart run example/rk_nats_example.dart
```

`sync_always.conf`:

```text
port: 4222
http_port: 8222
jetstream {
  store_dir: "./store"
  sync_interval: "always"
}
```

Without `sync_interval: "always"` the server acknowledges before fsync, the
client reports that plainly, and the example exits rather than pretending the
sale is safe.
