# Contributing

## Where the code comes from

This repository is a **public mirror**. Development happens in a private
monorepo and is carried across with `git subtree`. Commits made directly to
`main` here will be overwritten by the next transfer.

So: bugs and suggestions go in issues, and code changes go through a pull
request that is carried into the source by hand. That is inconvenient, and it
is more honest than accepting changes that would silently disappear.

## What gets checked

Everything CI does is reproducible locally, and **the native side goes first**:
the Dart suite loads the library the crate produces and fails loudly when it is
absent, so a test run before `cargo build` would be a green run over nothing.

This package is a Flutter FFI plugin, so its suite runs under `flutter test`
rather than `dart test`, and the Flutter SDK is needed as well as a Rust
toolchain.

```bash
cd rust
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
cd ..
flutter pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
flutter test
flutter pub publish --dry-run
```

## The two rules that are not style

**Nothing may send a multicast datagram out of one interface.** There is no
default-send path in this crate, and `rust/tests/every_interface.rs` is what
holds that open. A change that makes the send pick an interface — the cheapest
way to silence a duplicate — turns that suite red, and it is meant to.

**The parser is total.** `message.rs`, `name.rs` and `record.rs` read what
anything on the local segment chose to send. Every failure there is a returned
value. A `panic!`, an `unwrap` on parsed input, or an allocation sized from a
header field is a defect regardless of what the tests say.

## Proving a protocol change

A responder and a browser from the same source agree with each other whether or
not either agrees with the RFC, so **an interoperability check is required for
anything that touches the wire**. `doc/interop.md` holds the transcripts and
the exact commands: `avahi-browse` and `avahi-resolve` on Linux, `dns-sd` on
Apple. Attach the new transcript to the pull request.

## What a comment here is for

Every non-obvious decision in this package carries the measurement behind it,
not a restatement of the code. If you change one, change the reason with it —
and if there is no reason, that is worth finding out before the change lands.
