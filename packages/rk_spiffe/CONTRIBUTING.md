# Contributing

## Where the code comes from

This repository is a **public mirror**. Development happens in a private
monorepo and is carried across with `git subtree`. Commits made directly to
`main` here will be overwritten by the next transfer.

So: bugs and suggestions go in issues, and code changes go through a pull
request that is carried into the source by hand. That is inconvenient, and it
is more honest than accepting changes that would silently disappear.

## What gets checked

Everything CI does is reproducible locally:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

**There is no `cargo` line here, and there will not be one.** This package is
pure Dart with no native part; a native part is justified by a capability Dart
lacks or by code shared with another language, and parsing a grammar is
neither. The argument is set out in [`doc/architecture.md`](doc/architecture.md).

The last command is not about releasing. A package that cannot be published
breaks the build immediately rather than on the day of the release.

## Versions

Semantic, strictly. **There is no native part here, so the ABI clause the
other `rk_*` packages carry does not apply.** What is major here is the parser
changing its mind: a document that used to parse and no longer does, a
near-miss that used to be refused and is now accepted, or a renamed rule.
`SpiffeIdRule`, `X509SvidRule` and `JwtSvidRule` are part of the surface,
because callers switch on them.

The `CHANGELOG.md` entry is written in the same commit as the version bump, and
describes what changed **for the consumer**, not what went on inside.
