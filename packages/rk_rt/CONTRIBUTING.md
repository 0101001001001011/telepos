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
dart pub publish --dry-run
```

**There is no `dart test` line, and no `cargo` line, because there is neither
a `test/` directory nor a crate.** 0.0.1 is seventeen lines of Dart with a
probe that returns `false`, and there is nothing here to assert about. CI does
not print "skipped" for that: it checks that a `test/` directory is still
absent and fails the moment one appears, so that whoever adds the first test
also adds the line that runs it.

The last command is not about releasing. A package that cannot be published
breaks the build immediately rather than on the day of the release.

## Versions

Semantic, strictly. **There is no native part here, so the ABI clause the
other `rk_*` packages carry does not apply.** 0.0.1 promises nothing, and the
first version that promises something is where semantic versioning starts to
bite; the release that adds a control loop, a command set or telemetry is the
one that has to get the number right.

The `CHANGELOG.md` entry is written in the same commit as the version bump, and
describes what changed **for the consumer**, not what went on inside.
