## 0.2.2

- macOS and iOS actually build now: the pod script phase shipped with CRLF line endings and exited 0 without invoking cargo, so no Apple consumer could ever have built this package. The static archive also carried none of its exported symbols. Both fixed and verified on a Mac.

## 0.2.1

- Documentation is now in English throughout: `README.md`, `CONTRIBUTING.md`,
  `SECURITY.md`, both files under `doc/`, `example/example.md` and every
  changelog entry were in Russian and are not any more. No code and no API
  change.
- `doc/architecture.md` opened by describing the package as version 0.1.0 with
  the per-platform build mechanism missing. It has been present since 0.2.0.

## 0.2.0

- The package is now a Flutter FFI plugin: `flutter build` invokes cargo itself
  and puts the library in the application, on Windows, Linux and Android.
  Before this there was no `flutter.plugin.platforms` block in the pubspec, and
  the native part reached no build at all. macOS and iOS are written, but have
  never been built.

## 0.1.0

The first working release. This package is a **sink**, not a logging library:
it frames, spools and delivers records that already exist, and it cannot remove
logging calls from your code — said here, and in the README, so the next reader
does not wait for the impossible.

What arrived for the consumer:

- **RFC 5424 framing** — the whole header, structured data escaped per §6.3.3,
  a byte-order mark before the message per §6.4. A record that cannot be framed
  is **returned as a failure** naming the field that is wrong, on the caller's
  thread, rather than being dropped silently. An over-long record is truncated
  on a character boundary, and the fact of truncation is written into the
  record itself.
- **RFC 5425 delivery over TLS**, with octet counting rather than a newline.
  There is no built-in root store: either a root bundle or a pinned SHA-256
  fingerprint is required, or the sink does not open. Mutual TLS is supported.
- **A bounded on-disk spool**, with two rules to choose from: `drop_oldest`
  deletes the oldest segment, counts what was lost and writes a record saying
  so; `reject` deletes nothing and returns `spoolFull`. Neither loses anything
  silently. The bound is checked on every write, with no separate sweeper.
- **Submitting a record does not wait on the network.** Durability begins at
  the spool; `flush` is the explicit point, and it blocks only whoever called
  it.
- Ordering is preserved, across a restart too. Delivery is **at least once**;
  "exactly once" is not promised, because RFC 5425 has no acknowledgement to
  build it out of.
- Counters are read by name; an unknown name gives `unknownStat`, not zero.

For the Dart caller: failures come back as values rather than exceptions, and
`verifyNameTables()` compares the package's name tables against the loaded
library.

The C header is in `rust/include/rk_syslog.h` and is written by hand — it *is*
the description of the ABI. It will not drift from the library silently: a test
parses it and checks every status constant and every function name against the
exports.

Two things found before release, and therefore shipped nowhere:

- `flush` could return **before** the records were on disk, if the worker
  thread had already taken a batch before the call. An empty queue meant both
  "written" and "taken, but not yet written" at once; those states are now
  distinguished, and `flush` waits for the thing it exists for.
- The delivery cursor was being saved with an `fsync` for every record sent.
  The cursor says how far delivery has got, while the records themselves live
  in segments: losing the last cursor update costs a re-send, which at-least-
  once delivery already allows. With the barrier removed, the spool test run
  fell from 98 seconds to 5, and the till no longer takes a write barrier for
  every log record.

There is deliberately no per-platform build mechanism here — it is decided once
for all `rk_*` packages. Build the native part with
`cd rust && cargo build --release`.
