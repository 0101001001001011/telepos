# Contributing

## Where the code comes from

This repository is a **public mirror**. Development happens in a private
monorepo and is carried across with `git subtree`. Commits made directly to
`main` here will be overwritten by the next transfer.

So: bugs and suggestions go in issues, and code changes go through a pull
request that is carried into the source by hand. That is inconvenient, and it
is more honest than accepting changes that would silently disappear.

## What you need in order to build

**A Rust toolchain is required.** The core of this package is the crate under
`rust/`, and the tests build it rather than skipping it when it is absent. A
skip would be a green run that proves nothing about the boundary — exactly the
class of defect that the `anti-gaps` skill exists here to catch.

The crate deliberately has no dependencies: it must build on a machine that has
never seen the network, because it builds for tills.

## What gets checked

Everything CI does is reproducible locally, and **the native side goes first**:
the Dart suite loads the library the crate produces and fails loudly when it is
absent, so a `dart test` run before `cargo build` would be a green run over
nothing.

```bash
# the native side
cd rust
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
cd ..

# the Dart side
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

The last command is not about releasing. A package that cannot be published
breaks the build immediately rather than on the day of the release.

The workflow file in this directory runs only here, in the mirror, where this
directory is the repository root. In the private monorepo the same checks run
as one job of a nine-way matrix over all the `rk_*` packages, and that matrix
is what gates a merge. The two are obliged to say the same thing; where they
disagree, the monorepo's is right.

## Three tests that must not be weakened

- `test/no_raw_frame_test.dart` — walks the package's surface and fails if a
  single declaration returns anything byte-shaped. The roots of the walk are
  **derived from the `export` directives**, not maintained by hand.
- `test/isolate_discipline_test.dart` — fails on any synchronous method on the
  engine.
- `test/native_boundary_test.dart` — runs the model delivery chain end to end
  against the real library.

When you change any of them, break it on purpose and confirm that it goes red.
**And check with `grep` that your edit actually reached the source before you
ran it:** a mutation that silently failed to apply proves nothing, and that has
already happened twice here. The head of each file records exactly what to
break it with.

## The unfinished part names what is missing

The ONNX Runtime session path is not bound. It returns `NotImplemented` and
lists the missing `OrtApi` entry points. There must be no stub here that
silently returns an empty result: on a quiet camera such a stub is
indistinguishable from a working engine.

## Versions

Semantic, strictly. A change to the native ABI is **major**, even when no
signature on the Dart side changed: what the consumer loads at run time is now
a different thing.

The `CHANGELOG.md` entry is written in the same commit as the version bump, and
describes what changed **for the consumer**, not what went on inside.
