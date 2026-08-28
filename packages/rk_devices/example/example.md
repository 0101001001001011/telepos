# Example

A runnable version of this file is `example/rk_devices_example.dart`. It needs
the native crate built first:

```sh
cd rust && cargo build --release
```

## Loading

```dart
import 'package:rk_devices/rk_devices.dart';

final devices = RkDevices.tryOpen();
if (devices == null) {
  // No native library for this host. A third state, not an error.
  return;
}
```

## A scale

Ask for a weight, feed the bytes back in, and let the settling rule decide.
The loop is yours — this package never waits.

```dart
final request = devices.scaleWeightRequest(ScaleProtocol.cas); // W\r
port.write(request);

final rule = devices.stabilizer(budget: const Duration(seconds: 5));
final started = DateTime.now();
var buffer = Uint8List(0);
try {
  while (true) {
    final chunk = await port.read();
    buffer = Uint8List.fromList([...buffer, ...chunk]);

    var heard = chunk.isEmpty ? Heard.silence : Heard.noise;
    WeightReading? reading;

    final frame = devices.scaleParse(ScaleProtocol.cas, buffer);
    if (frame is ScaleReadingFrame) {
      reading = frame.reading;
      heard = Heard.reading;
    }
    if (frame.consumed > 0) {
      buffer = Uint8List.sublistView(buffer, frame.consumed);
    }

    final verdict = rule.offer(
      elapsed: DateTime.now().difference(started),
      heard: heard,
      reading: reading,
    );
    switch (verdict) {
      case SettleVerdict.settled:
        print('weigh ${reading!.toDecimalString()} ${reading.unit.wireName}');
        return;
      case SettleVerdict.notYet:
        continue;
      case SettleVerdict.expired:
        print('the scale answers but the weight has not settled');
        return;
      case SettleVerdict.noAnswer:
        print('nothing on the port — check the cable, baud rate and protocol');
        return;
    }
  }
} finally {
  rule.dispose();
}
```

`expired` and `noAnswer` are different facts. Reporting both as one timeout is
what used to send operators to look at the pan when the cable was out.

## A customer display

```dart
final total = devices.displayEncode(
  model: DisplayModel.vfd20,
  op: DisplayOp.writeLine,
  line: 0,
  text: 'ИТОГО:',
);
if (total.substitutions > 0) {
  // CP866 has no Kazakh or Kyrgyz letters and no ₸. The customer is being
  // shown something other than what was asked for, and now you know.
}
port.write(total.bytes);
```

## A cash drawer

Three outcomes, and the compiler makes you handle all three.

```dart
switch (cashDrawerPulse()) {
  case DrawerPulseBytes(:final bytes):
    await printer.writeRaw(bytes);   // ESC p 0 0x20 0xA0
  case DrawerPulseRefused(:final status):
    log('drawer request refused: $status');
  case DrawerPulseUnsupportedHere():
    log('no drawer support on this machine');
}
```

Whether the drawer physically opened is a question nobody can answer:
`devices.drawerReporting(DrawerModel.escposKick)` says `cannotReport`, and a
caller must not claim otherwise.

## MDB

Frames for a bridge microcontroller to put on the bus. The five-millisecond
window is a number to configure that bridge with — this package cannot hold
it, because it never waits.

```dart
final poll = devices.mdbEncode(MdbAddress.coinChanger, 'poll');
// [0x10B, 0x00B] — bit 8 is the mode bit, on the command byte only.

switch (devices.mdbDecode(await bridge.read())) {
  case MdbBlock(:final payload): handle(payload);
  case MdbAck():                 break;
  case MdbNak():                 retry();
  case MdbRet():                 resend();
  case MdbIncomplete():          break;      // keep the words, read more
  case MdbBadChecksum():         resend();
}
```

## A partial write

```dart
var pending = payload;
while (true) {
  final accepted = port.write(pending);   // negative means it failed
  final next = remainingAfterWrite(
    devices: devices,
    wire: Wire.serial,
    payload: pending,
    accepted: accepted < 0 ? null : accepted,
  );
  if (next == null) break;                 // done
  pending = next;                          // the rest — never the whole thing
}
```

On a socket or a raw USB node the same call throws `RkDevicesUnavailable`,
because those transports cannot say how much reached the device. The retry
belongs one layer up, where the job has an identity that makes a repeat safe.
