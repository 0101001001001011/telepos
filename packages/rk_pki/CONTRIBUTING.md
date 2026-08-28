# Contributing

## Where the code comes from

This repository is a **public mirror**. Development happens in a private
monorepo and is carried across with `git subtree`. Commits made directly to
`main` here will be overwritten by the next transfer.

So: bugs and suggestions belong in issues; code changes go through a pull
request, which is carried into the source by hand. That is inconvenient, and it
is more honest than accepting patches that would silently disappear.

## What is checked

Everything CI does can be reproduced locally, and **the native side goes
first**: the Dart suite loads the library the crate produces and fails loudly
when it is absent, so a `dart test` run before `cargo build` would be a green
run over nothing.

```bash
cd rust
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
cd ..

dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

A Rust toolchain is therefore required to check a change here.

The last command is not about releasing. A package that cannot be published
breaks the build immediately, rather than on release day.

## Versions

Semantic, strictly. A change to the native ABI is **major**, even when no Dart
signature changed: what the consumer loads at run time is now a different
thing.

The `CHANGELOG.md` entry is written in the same commit as the version bump, and
describes what changed **for the consumer**, not what was going on inside.
