# Example

A till announces that it is alive, listens for commands addressed to its durable
name, and publishes a heartbeat. Nothing here runs on the calling isolate.

```dart
import 'dart:convert';

import 'package:rk_zenoh/rk_zenoh.dart';

Future<void> main() async {
  final session = await ZenohSession.open(ZenohConfig(
    mode: SessionMode.peer,
    connect: ['tcp/127.0.0.1:7447'],
  ));

  // Address by durable name, not by Zenoh ID: the ID changes on every
  // restart, and sending to the old one succeeds while delivering nothing.
  final alive = await session.declareLiveliness('telepos/alive/till-17');
  final orders = await session.subscribe('telepos/till/till-17/cmd');
  orders.samples.listen((s) => print('${s.key}: ${s.text}'));

  await session.put('telepos/shop/3/heartbeat', utf8.encode('ok'));

  await orders.close();
  await alive.close();
  await session.close();
}
```

`example/rk_zenoh_example.dart` is the runnable version: it stands a shop server
and a till up in one process, restarts the till, and shows that addressing by
durable identity survives the restart while addressing by the remembered Zenoh
ID does not — and that the failure is silent.

```
cd rust && cargo build --release
dart run example/rk_zenoh_example.dart
```
