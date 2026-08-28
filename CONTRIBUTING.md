# Contributing to TelePOS

Thanks for taking the time. TelePOS runs real tills handling real money, so the
bar for changes is "would I trust this at a counter on a Saturday". This
document explains how to get there.

## Getting set up

```bash
flutter --version          # 3.47 or newer, Dart SDK ^3.13.0
flutter pub get
flutter gen-l10n           # regenerate lib/l10n from assets/i18n
flutter test
```

Desktop builds need the usual toolchains: Visual Studio with the "Desktop
development with C++" workload on Windows, `clang`/`cmake`/`ninja`/`libgtk-3-dev`
on Linux, Xcode on macOS.

Run the app with `flutter run -d windows` (or `linux`, `macos`, `chrome`).

## The rules that are not negotiable

**Money is `Decimal`, never `double`.** Every monetary and quantity value uses
`package:decimal` at precision 18, scale 3. A single `double` in a price path
produces receipts that do not balance. If you find yourself reaching for
`toDouble()` on a money value, something upstream is wrong.

**Layers point inward.** `domain/` is pure Dart with no Flutter and no
infrastructure imports. `data/` implements domain interfaces and owns drift,
HTTP and platform channels. `presentation/` owns widgets and Riverpod
controllers, and talks to `domain/` — never to `data/` directly.

```
lib/
  domain/         entities, repository interfaces, use case interfaces
  data/           drift database, DAOs, repository and use case implementations
  presentation/   screens, widgets, Riverpod controllers
  telegram/       TDLib client, bots, channels, sync engine
  transport/      pluggable transports (CouchDB, Telegram, legacy REST)
  wire/           the QUIC/WebTransport contract between till and terminal
  hardware/       printers, scanners, scales, cash drawer, customer display
  app/            DI (get_it + injectable), router, theme, config
  core/           constants, utilities, localization plumbing
```

**No secrets in the repository.** Telegram API credentials, fiscal operator
keys and passwords are supplied at build time via `--dart-define` or entered by
the operator at runtime. See [SECURITY.md](SECURITY.md).

**User-facing strings are localized.** Add the key to all five ARB files in
`assets/i18n/` (`ru` is the template), then run `flutter gen-l10n`. Never
hardcode a display string in a widget.

## Code generation

Drift, freezed, json_serializable, injectable and riverpod all generate code.
After changing a table, a freezed class or an injectable annotation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) are committed — do not edit them
by hand.

**Database schema changes** need a migration. Bump the schema version in
`lib/data/database/app_database.dart` and add the migration step; existing tills
carry live data and cannot be reset.

## Tests

```bash
flutter test                       # everything
flutter test test/e2e              # end-to-end journeys against a real DB
flutter test test/e2e/ui_showcase_test.dart --update-goldens   # refresh README screenshots
```

`test/e2e/support/harness.dart` boots the real DI graph against an in-memory
drift database, so end-to-end tests exercise actual repositories and use cases
rather than mocks. Prefer adding to those over widget tests with stubs.

Two things about the current suite you should know before you panic:

- Tests tagged `live` reach a real backend over the network and are skipped by
  default via `dart_test.yaml`. Opt in with `flutter test --tags live`; expect
  failures, since the backend they target is being retired.
- Golden comparisons under `test/e2e/` are non-gating (see
  `test/e2e/flutter_test_config.dart`) — a differing screenshot prints a note
  rather than failing. Goldens under `test/golden/` **do** gate locally, so a
  change to a screen's chrome means running
  `flutter test test/golden --update-goldens` and committing the result.

  Those images were rendered on Windows, and font rasterization differs enough
  between platforms that the same UI diffs by several percent on Linux. They
  are therefore tagged `golden` and excluded from the gating run
  (`--exclude-tags golden`). If you develop on Linux or macOS, expect them to
  fail locally and do not regenerate them — that would just move the problem to
  everyone else. Pinning golden rendering to one platform properly means running
  them in a fixed container, which is not set up yet.

  One trap worth knowing, because it cost us a broken build: **the `golden` tag
  excludes those files from the run entirely, which means it also excludes them
  from being compiled.** A sweeping edit can leave a golden test file that does
  not parse and a completely green gating run. After any wide change, run
  `flutter test --tags golden` too — it takes about forty seconds.

## We do not accept pull requests

**This is a closed-development project, and that is deliberate.** TelePOS is
written by its own team, and code is merged only by that team. Pull requests
opened against this repository will be closed unread — not out of rudeness, but
because reviewing them honestly is a promise we cannot keep, and leaving them
open for months would be worse than closing them today.

**What you may do instead, and what the licence guarantees you can:**

- **Fork it.** The AGPL gives you the right to take the code, change it and run
  it, and nothing here restricts that. Your fork is yours.
- **Distribute your fork**, provided you keep it under the AGPL and offer your
  users its source — including when they reach it over a network.
- **Report what you find.** Bug reports, reproductions and test cases are the
  contribution we want and will act on. See below.
- **Ask.** An issue asking "why is it done this way" is welcome and often the
  most useful thing in the tracker.

**Why closed development.** This code takes money at a counter. A defect here
is not a broken page — it is a till that ends the day short, or a receipt that
was never fiscalized. Merging code we did not write means vouching for it at
that standard, and we would rather say plainly that we cannot than accept
patches and review them thinly.

This decision is about code, not about people. Everything else — testing,
reports, questions, criticism, forks — is open, and the parts of the project we
most need help with are exactly the parts that do not require merge rights.

## Reporting bugs

Use the issue templates. For anything involving incorrect amounts, include the
receipt, the products involved and the payment split — "the total was wrong" is
not reproducible.

Security issues do not go in the issue tracker — see [SECURITY.md](SECURITY.md).

## If you are here to test rather than to write code

This is the contribution we most need, and it does not require Dart.

**Where the value is.** The paths named in the project status section of the
[README](README.md) are the ones nobody has hammered: first launch and the setup
wizard, small screens, stylus input, and anything outside Kazakhstan. Automated
tests cover the happy paths well and the first ten minutes of a stranger's
experience not at all.

**What a useful report contains.** Which platform and build, what you did step
by step, what you expected, what happened. For anything touching money: the
receipt, the products, the payment split, and the amounts you expected. "The
total was wrong" cannot be reproduced; "1 item at 2250, 10% line discount,
paid 2000 cash + 25 card, receipt shows 2025 instead of 2025.00" can.

**Things that are already known** are listed in the README's status table and in
`docs/internal/ROADMAP.md`. A report confirming a known defect is still useful if
it adds a reproduction we do not have — say so, rather than assuming it is a
duplicate and staying quiet.

**Exploratory testing beats writing test cases first.** Go and break it, then
write down what broke. We will turn a good reproduction into a regression test.

## Licence of contributions

TelePOS is licensed under the GNU Affero General Public License v3.0 or later.
We do not accept pull requests (see above), so there is no contributor licence
agreement and nothing for you to sign. If you fork, your fork carries the same
licence and the same obligations.

The libraries under `packages/rk_*` are published separately under MIT and stay
MIT; a contribution to one of those is under MIT rather than AGPL. The
`LICENSE` file inside each package is the authority, not this paragraph.
