# Contributing

## Where the code comes from

This repository is a **public mirror**. Development happens in a private
monorepo and is carried across with `git subtree`. Commits made directly to
`main` here will be overwritten by the next transfer.

So: bugs and suggestions go in issues, and code changes go through a pull
request that is carried into the source by hand. That is inconvenient, and it
is more honest than accepting changes that would silently disappear.

## What gets checked

Everything CI does is reproducible locally, and **the native side goes
first**: the Dart suite loads the library the crate produces and fails loudly
when it is absent, so a test run before `cargo build` would be a green run over
nothing.

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

The last command is not about releasing. A package that cannot be published
breaks the build immediately rather than on the day of the release.

## Versions

Semantic, strictly. A change to the native ABI is **major**, even when no
signature on the Dart side changed: what the consumer loads at run time is now
a different thing.

The `CHANGELOG.md` entry is written in the same commit as the version bump, and
describes what changed **for the consumer**, not what went on inside.
