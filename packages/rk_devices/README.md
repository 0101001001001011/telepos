# rk_devices

Device protocols that carry their own timing — framed, parsed, and never
waited on.

Weighing scales, customer displays, cash drawers and MDB vending framing. One
implementation of each conversation instead of one per transport.

## The rule this package is shaped by

**Timing that a peripheral controller owns stays there.** MDB's
five-millisecond reply window and a stepper's microsecond pulses are held by
hardware timers and UARTs, not by a general-purpose host running a till. So
this package speaks protocols and holds no deadlines: it frames, parses and
reports.

Concretely, the native library performs no I/O, opens nothing, sleeps never
and spawns no thread. Every call is a pure function of its arguments. Nothing
that cannot wait can make anyone wait.

The one place time appears is the settling rule for scales, and it holds no
clock either: the caller supplies the elapsed time on every offer, and the
budget is a `Duration` rather than a number of attempts.

## What it covers

| Area | Depth |
| --- | --- |
| Scales | Weight and tare requests, line framing, three dialects (`generic`, CAS, Massa-K), stable/moving/overload/underload, gross/net, unit as read — in every dialect, and never assumed. A sign padded away from its digits (`-  0.500kg`, how a scale right-justifies a number) keeps its sign. Over capacity is reported even when the value slot is blank. Massa-K has no established overload marker and none is invented here: such a frame parses, never settles, and is reported as "answered, never settled" rather than as a guessed refusal. A settling rule that tells "never settled" apart from "never answered". |
| Customer displays | Reset, clear, home, on/off, blink, brightness, cursor, line writing. CP866, with unmappable characters **counted** rather than silently spaced. Three models: `led8`, `vfd20`, `lcd2x20`. |
| Cash drawers | The `ESC p m t1 t2` kick pulse, both pins, times in milliseconds rounded up to the protocol's two-millisecond units. And an honest `cannot_report`: the kick wire is one-directional. |
| MDB | Nine-bit words with the mode bit, the block checksum, ACK/NAK/RET, a named command table for changer, bill validator and both cashless addresses, and a raw path that bypasses the table. **No bus timing.** |
| Partial writes | What a remainder means on a serial port, on a socket, and on a raw USB node — which are three different answers. |

## Weight is not a float

A reading comes back as an integer and a decimal exponent, plus the unit the
scale itself named. Nothing is converted: a unit conversion is a rounding
decision about a number that is about to be multiplied by a price, and that
decision does not belong in a codec.

```dart
final frame = devices.scaleParse(ScaleProtocol.cas, bytes);
if (frame is ScaleReadingFrame) {
  frame.reading.toDecimalString(); // '1.234' — exact, no double anywhere
}
```

## Partial writes differ per wire

| wire | what a write returns | what a remainder means |
| --- | --- | --- |
| `serial` | a byte count | a **continuation** — send the rest, never the whole thing again |
| `socket` | nothing | unknowable: a failed flush does not say how much reached the wire |
| `usb_raw` | nothing | unknowable, and the driver may have taken part of it |

A partial count claimed for a socket or a raw USB node is **refused**, not
believed. FFI creates no information the transport does not have.

## Building the native part

The crate lives in `rust/` inside this package and builds to a `cdylib` and a
`staticlib` with a plain C ABI (`rust/include/rk_devices.h`).

```sh
cd rust && cargo build --release
```

This package is a **Flutter FFI plugin**: `flutter build` runs cargo and puts
the library in the application, on Windows, Linux and Android. There is no
`hook/` directory here and there will not be — its mere presence breaks
`dart run`, `dart test` and `flutter build`. The mechanism, the three separate
routes to cargo and what to check first on a Mac are in
[`doc/native-build.md`](doc/native-build.md).

For development and tests the Dart binding finds the library by searching, in
order: an explicit path, `RK_DEVICES_LIBRARY`, the platform's default name
through the system loader, and `rust/target/{release,debug}`. Inside a built
application the third step is the one that fires.

**Where it has been proved to arrive:**

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrives | `rk_devices.dll` next to the runner of a built application |
| Linux | arrives | `librk_devices.so` in the application's `bundle/lib/` |
| Android | arrives | found **inside the unpacked APK** for `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| macOS, iOS | **built and linked** | verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2: the archive builds for arm64 and x86_64 on macOS, arm64 on device and both on the simulator; a C probe links against it with `-force_load` in Release and Debug, and the macOS binaries run through the C ABI. Gated by CI from that day. |

## Rules this package holds itself to

- **A native failure is a returned value**, never an exception across the FFI
  boundary and never a crashed process. Every entry point catches panics; the
  crate refuses to compile under `panic = "abort"`.
  `RkDevices.provokePanicForTest()` exists so a consumer can prove this rather
  than assume it.
- **Freeing is deterministic, and Dart's garbage collector is never asked
  about native memory.** The library allocates nothing that crosses the
  boundary — every result is written into a caller-owned buffer — so "who
  frees what" has a one-word answer.
- **Enumerations cross by name, never by number.**
- **No device failure blocks taking money.** Structural: there is no wait here
  to be unbounded.

## What has never met a device

Everything. There is no hardware in the development environment. Every byte
sequence in this package is checked against a test, and the scale, display and
drawer sequences are checked against the bytes the consuming product has been
sending to real tills for years. The MDB address and command table is
transcribed from secondary engineering sources — the NAMA standard is not
freely distributed — and has never been on a bus. `mdbEncodeRaw` exists for
exactly that reason.

## License

MIT, Rob Kim. See `LICENSE`.
