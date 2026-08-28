## 0.2.2

- macOS and iOS actually build now. The pod script phase shipped with CRLF line endings and exited 0 without invoking cargo, both Apple platforms need Security and CoreFoundation which the podspecs did not name, and the Dart loader asked for a dylib that is never produced. All fixed and verified on a Mac.

## 0.2.1

- Documentation is now in English throughout: README, CHANGELOG, CONTRIBUTING, SECURITY, doc/ and the example. The example in example/example.md was also stale — it called rkZenohVersion and hasNativeSession, which have not existed since 0.1.0 — and now shows the real API.

## 0.2.0

- The package became a Flutter FFI plugin: `flutter build` now invokes cargo itself and puts the library into the application on Windows, Linux and Android. Before this there was no `flutter.plugin.platforms` block in the pubspec, and the native side reached no build at all. macOS and iOS are written but have never been built.

## 0.1.0

First working version. 0.0.1 held the name and did nothing; nothing of it
survives, including `rkZenohVersion` and `hasNativeSession` — those are gone.

- The `rust/` crate: a C ABI over a **stable subset** of Zenoh 1.9.0. The
  `unstable` feature is not enabled, so Advanced Pub/Sub — publisher cache,
  history for late subscribers, gap detection and recovery — is absent, as are
  liveliness history and per-message reliability. What that means in practice is
  written up in `doc/stable-subset.md`.
- `ZenohSession`: open, `put`, `delete`, subscribe, liveliness tokens, and the
  list of reachable nodes. Every native call happens on a worker isolate the
  package creates itself; nothing runs on the caller's isolate.
- `ZenohIdentity` forces a decision about whether the Zenoh ID survives a
  restart. A pinned ID **is rejected without TLS**: it was measured that
  whoever claims it first keeps it — so a machine that knows a till's name cuts
  that till out of the fabric by booting earlier. The numbers and both ways out
  are in `doc/stale-zid.md`.
- Failure comes back as a returned value; panics are caught at the boundary.
  The kind of failure crosses the boundary **by name** (`RkzErrorKind`), as do
  modes, priorities, congestion control and sample kind.
- Freeing is deterministic and one-way: whoever received a handle frees it. The
  table is in `doc/architecture.md`.

The package deliberately ships no per-platform build scaffolding: `cd rust &&
cargo build --release`, and the library is located by an explicit path, by
`RK_ZENOH_LIBRARY`, or next to the executable.

## 0.0.1

- Name claimed. No content yet: the package exercises the publishing pipeline
  rather than solving the problem.
