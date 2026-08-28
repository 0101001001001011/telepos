# rk_quic

QUIC and WebTransport for Dart over a native library.

Dart has no QUIC of its own — both requests in the SDK tracker are closed as
"not planned" — so the implementation is written in Rust behind a C ABI and
reached through `dart:ffi`. The point of all of it is one thing: **the server
gets the right to speak first.** A change in the state of a print job, a device
that appeared or failed, reaches a browser client at the moment of the event
rather than the next time somebody asks.

## What 0.2.1 can do

Serve WebTransport to a browser — and **speak first**. Since 0.2.0 an exchange
can also be a bidirectional stream, so an answer can be told apart from the
question it belongs to when several are in flight at once.

```dart
import 'package:rk_quic/rk_quic.dart';

Future<void> main() async {
  final start = await QuicServer.start(QuicServerConfig(
    bindAddress: '0.0.0.0:4433',
    certificateChainPem: chainPem,   // issued by rk_pki, not by this package
    privateKeyPem: keyPem,           // PKCS#8
  ));

  final server = start.server;
  if (server == null) {
    // portInUse, badCertificate, invalidArgument, unsupported — a value,
    // not an exception. The till carries on selling.
    print(start);
    return;
  }

  server.events.listen((event) {
    if (event is SessionOpened) {
      // Nobody asked. We tell them.
      server.send(event.sessionId, 'print job 41 printed');
    }
  });
}
```

Everything here that blocks — waiting for an event and sending reliably — lives
on helper isolates: the interface isolate makes not one call into the native
part.

## Bind to `[::]` to reach both families

`0.0.0.0` is IPv4 and nothing else. `[::]` is **both**, and since 0.2.1 that is
true on every operating system rather than on some of them: the endpoint now
asks for dual stack explicitly instead of leaving `IPV6_V6ONLY` at a default
that Linux and Windows disagree about. This matters more than it sounds, because
a browser resolves `localhost` and a machine name to IPv6 first — under the old
behaviour a Windows host answered `curl` and left Chrome timing out.

The order of work was chosen deliberately: first an empty library was made to
arrive at every reachable target, and only then was the transport laid on top of
a proven mechanism. An empty library has no reasons of its own to fail, so a red
build meant a broken pipeline and nothing else.

```dart
print(rkQuicVersion);       // 0.2.1 — read out of the loaded library
print(hasNativeTransport);  // true if it opened and the ABI generation agreed
```

In 0.0.1 `rkQuicVersion` was a `const String`; it is now a `String?`. That is
what the version was raised for: a constant would go on reporting the right
version while a year-old library sat next to it.

## Certificates are issued by rk_pki, not by this package

A certificate has **one representation** across both packages:
`rustls_pki_types::CertificateDer`. PEM is only the shape in which it crosses
the FFI boundary. `rk_quic` cannot mint certificates and will not: two packages
with a certificate authority each is an installation with two authorities that
nobody chose between.

## Why quinn and not quiche

The usual argument for quiche is its ready-made C API. It does not apply here:
**we do not consume that API, we write one.** This package is a cdylib with an
`extern "C"` surface of its own, so quiche's C API is not a benefit and quinn's
lack of one is not a cost.

What decides it is something else: `rk_pki` is being built alongside on rustls +
aws-lc-rs, and the certificate chain has to be one type from one crate on both
sides. quinn on rustls is exactly that. quiche's TLS is BoringSSL: a second
stack, a second certificate type with conversion between them, and a BoringSSL
build (CMake plus Go) on all six targets — against the one thing this package
has so far managed to prove.

## A failure is a value, not an exception

Nothing here throws an exception because the native part is absent, old or
unwell, and nothing brings the process down. Every outcome is a value:

| `NativeLoadOutcome` | What it means |
| --- | --- |
| `loaded` | usable, the ABI generation matched |
| `unsupportedPlatform` | the browser: there is no `dart:ffi`, and that is permanent |
| `libraryMissing` | there is nothing to open under any of the names tried |
| `symbolMissing` | it opened, but it does not export the rk_quic ABI |
| `abiMismatch` | it works, and it speaks a generation this build does not know |

`abiMismatch` is refused rather than used carefully: calling across a generation
is a way to break memory ownership rules silently, and it surfaces as an
unexplained crash an hour later.

Statuses arrive from the native part **by name**, never by number: `"portInUse"`,
not `4`. An unfamiliar name becomes `RkQuicStatus.unrecognised` rather than
somebody else's branch.

## Which platforms the library reaches

| Platform | State |
| --- | --- |
| Windows | built and called: `rk_quic.dll` (3.5 MB) next to the runner |
| Linux | built and called: `librk_quic.so` (5.3 MB) in `bundle/lib/`; the whole test suite, including a live WebTransport session, is green |
| Android | built and packaged: `librk_quic.so` in `lib/{armeabi-v7a,arm64-v8a,x86_64}` inside the APK (2.3–5.3 MB per slice) |
| macOS, iOS | **built and linked** — verified 2026-08-03 on macOS 26.2 / Xcode 26.2, Release and Debug, all three Apple platforms; see `doc/native-build.md` |
| Web | no native part, by design: the browser is a client of this endpoint, not its host |

Importing this package from code that also builds for web is safe: `dart:ffi`
is behind a conditional import, and it is absent from the browser half.

## Who frees what

In this version there is nothing for the caller to free. The version string
points into the library's static memory and lives as long as the process does.
Where the library does allocate — the detail of a failure — the buffer is
returned through `rk_quic_string_free`, and Dart never calls `free()` on it
itself. The rule is one-sided: **whoever allocated frees.**

## Building the native part

`cd rust && cargo build --release` — or let the Flutter build do it. What each
platform requires, and the two places where the platforms diverge, are in
[`doc/native-build.md`](doc/native-build.md).

## Licence

MIT, Rob Kim. See `LICENSE`.
