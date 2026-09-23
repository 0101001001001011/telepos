<div align="center">

<img src="assets/icons/telepos_icon_1024.png" width="128" alt="TelePOS">

# TelePOS

**Telegram Point of Sale** — an offline-first point of sale that keeps working
when the internet does not.

[![Tests](https://img.shields.io/badge/tests-5979%20passing-2ECC71.svg)](#development)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-1ABC9C.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue.svg)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-alpha-E67E22.svg)](#project-status)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg)](#building)

<img src="docs/screenshots/02-sale.png" width="820" alt="TelePOS sale screen">

</div>

---

## Project status

**Alpha. It sells, and it is not finished.** Read this section before anything
else — we would rather lose you here than an hour into a broken first launch.

*Verified working:* a full sale on a real till (search, cart, mixed payment,
receipt), shifts with X/Z reports, refunds against the original receipt,
catalog, stock, warehouse operations, restaurant tables and service jobs. The
browser terminal reaches the till over QUIC and has been checked on a genuine
second device, not just on loopback. 3585 automated tests pass, of which 57 are
end-to-end journeys booted against the real dependency-injection graph.

*Known broken or unproven, in the order that will bite you:*

| Area | State |
| --- | --- |
| **First launch and setup wizard** | Historically the weakest path in the product. This is the first thing a new tester meets, and the first thing we want reported |
| **Sync between tills** | CouchDB replication has four verified defects — revisions are not sent on push, errors are swallowed, only one document type of twelve is pulled. **A multi-till shop does not sync today** |
| **Countries other than Kazakhstan** | Only KZ has ever been tested end to end. Russian, Kyrgyz and Uzbek VAT rates, tax-id formats and masks are unvalidated, and we know of one outright contradiction in our own constants |
| **Small screens and stylus input** | Layout breaks below tablet width; scrolling with a stylus is poor |
| **Continuous integration** | There is none. The workflow that once existed was failing and was not the gate anyway; a red badge nobody acts on is worse than an honest gap, so it was switched off. The real gate today is the local suite plus a build, described in [Development](#development). Building CI that actually gates is one of the larger open pieces of work |

**We are looking for QA.** Not for polish — for the boring, valuable work of
finding out what breaks: exploratory testing, reproducible bug reports, test
cases for the paths above, and honest reports of what a first-time operator
cannot figure out. Open an issue, or start from
[CONTRIBUTING.md](CONTRIBUTING.md).

## What it is

TelePOS is a complete point-of-sale system for small and medium retail. It runs
on the till itself — catalog, stock, shifts, receipts and reports all live in a
local SQLite database, so a dropped connection is an inconvenience rather than
an outage.

It covers four kinds of business out of one codebase:

| Mode | What it adds |
| --- | --- |
| **Retail** | Barcode selling, weighted goods, promotions, loyalty |
| **Restaurant** | Table map, running orders, course firing, split bills |
| **Service** | Repair intake, job queue, warranty and quality tracking |
| **Warehouse** | Cells, batches, serials, claims, marking codes |

## Why it exists

**Money is exact.** Every amount and quantity is a `Decimal` at precision 18,
scale 3 — never a `double`. Floating-point cents are how a till ends the day
sixty tenge short with nobody able to say why.

**The network is optional.** Sales complete, receipts print and the cash drawer
opens with no server reachable. Synchronization is something that happens
afterwards, not a precondition for taking money.

**No vendor in the middle.** You run the database. There is no TelePOS cloud
account to depend on, no per-terminal subscription, and nothing that stops
working if this repository goes quiet.

## Two ways to connect your tills

A single till needs neither. Once there are several, pick whichever fits:

```mermaid
graph LR
    subgraph "CouchDB replication"
        P1[Till 1] <--> C[(CouchDB)]
        P2[Till 2] <--> C
        P3[Till 3] <--> C
        C <--> W[Web admin panel]
    end
    subgraph "Telegram transport"
        T1[Till 1] <--> TG(( Telegram ))
        T2[Till 2] <--> TG
        TG --> O[Owner's phone:<br/>reports and alerts]
    end
```

**CouchDB** is meant to give bidirectional, conflict-aware replication between
tills. It does not work yet: see [Project status](#project-status). The code is
in the tree, the defects are known and named, and repairing it is one of the
largest open pieces of work.

**Telegram** turns private channels into the transport: sales, shifts, price
updates and backups move between points as encrypted messages, and the owner
gets reports on their phone without any infrastructure at all. Useful where
running a server is not realistic — a kiosk on mobile data, a stall, a shop with
one laptop.

Telegram mode is off by default. Turn it on in **Settings → Telegram** and
supply your own application credentials (see [Configuration](#configuration)).

## Screenshots

| | |
| --- | --- |
| <img src="docs/screenshots/02-sale.png" alt="Sale"> **Sale** | <img src="docs/screenshots/03-payment.png" alt="Payment"> **Payment** |
| <img src="docs/screenshots/04-shift.png" alt="Shift"> **Shift and cash** | <img src="docs/screenshots/06-reports.png" alt="Reports"> **Reports** |
| <img src="docs/screenshots/07-catalog.png" alt="Catalog"> **Catalog** | <img src="docs/screenshots/08-supply.png" alt="Supply"> **Supply** |
| <img src="docs/screenshots/10-restaurant-tables.png" alt="Tables"> **Restaurant tables** | <img src="docs/screenshots/11-service-queue.png" alt="Service queue"> **Service queue** |
| <img src="docs/screenshots/12-warehouse.png" alt="Warehouse"> **Warehouse** | <img src="docs/screenshots/14-telegram.png" alt="Telegram"> **Telegram transport** |

<details>
<summary>More screens</summary>

| | |
| --- | --- |
| <img src="docs/screenshots/01-login.png" alt="Login"> **Login** | <img src="docs/screenshots/05-history.png" alt="History"> **Receipt history** |
| <img src="docs/screenshots/09-stock.png" alt="Stock"> **Stock registry** | <img src="docs/screenshots/13-promotions.png" alt="Promotions"> **Promotions** |
| <img src="docs/screenshots/15-settings.png" alt="Settings"> **Settings** | |

</details>

### Dark theme

Both themes follow Telegram Desktop: the light one is its day palette, the dark
one its Night palette — a blue-tinted `#0E1621` canvas rather than neutral grey.
The navigation column collapses to icons and is collapsed by default; these
shots have it expanded so the sections are readable.

| | |
| --- | --- |
| <img src="docs/screenshots/21-sale-dark.png" alt="Sale, dark"> **Sale** | <img src="docs/screenshots/22-catalog-dark.png" alt="Catalog, dark"> **Catalog** |
| <img src="docs/screenshots/23-reports-dark.png" alt="Reports, dark"> **Reports** | <img src="docs/screenshots/24-warehouse-dark.png" alt="Warehouse, dark"> **Warehouse** |
| <img src="docs/screenshots/25-settings-dark.png" alt="Settings, dark"> **Settings** | <img src="docs/screenshots/20-login-dark.png" alt="Login, dark"> **Login** |

Every screenshot in this file is generated by
`flutter test test/e2e/ui_showcase_test.dart --update-goldens`, which drives the
real application through the real dependency-injection graph against a seeded
database. They are not mock-ups, and they cannot drift from the product without
the command being re-run.

## Features

**Selling.** Barcode and name search, weighted goods, quick-product grid,
deferred receipts, line discounts, mixed cash-and-card payments, partial and
full refunds against the original receipt.

**Shifts and cash.** Open and close shifts, X- and Z-reports, cash in and out,
counted-versus-expected reconciliation, per-account cash and card breakdown.

**Catalog and pricing.** Categories, multiple price levels, automatic markup
rules applied at goods receipt, label and price-tag printing with a built-in
template editor.

**Stock.** Goods receipt, supplier orders and returns, write-offs, inter-store
movement, stocktaking, reorder-point signals, and an oversell policy you can set
to warn or block.

**Warehouse (WMS).** Multi-warehouse with cell addressing, batch and serial
tracking, claims handling, and marking-code registration.

**Promotions and loyalty.** Percentage and fixed discounts, 1+1 and gift
mechanics, customer accounts with bonus accrual and capped redemption.

**Fiscalization.** Pluggable providers — WebKassa, Kassa24, direct OFD — with an
offline queue that fiscalizes retroactively once connectivity returns. Kazakh
ESF/SNT and marking flows route through the configured operator.

**Hardware.** ESC/POS receipt printers over USB, serial and network; label
printers; barcode scanners in keyboard-wedge mode; scales; cash drawers;
customer displays including a second-monitor mode; Kaspi payment
integration.

**Localization.** English, Russian, Kazakh, Kyrgyz and Uzbek, with the currency,
tax rate, tax-id format and phone mask following the selected country.

## Architecture

Domain-driven, with dependencies pointing inward. `domain/` is pure Dart and
knows nothing about Flutter, drift or HTTP.

```mermaid
graph TD
    UI[presentation/<br/>screens, widgets, Riverpod controllers]
    DOM[domain/<br/>entities, repository and use case interfaces]
    DATA[data/<br/>drift database, DAOs, implementations]
    TG[telegram/<br/>TDLib, bots, channels, sync]
    HW[hardware/<br/>printers, scanners, scales]

    UI --> DOM
    DATA --> DOM
    TG --> DOM
    HW --> DOM
```

| Piece | Choice |
| --- | --- |
| State | Riverpod (`Notifier`, not auto-dispose) |
| Dependency injection | get_it + injectable |
| Database | drift over SQLite — 91 tables, schema v36 |
| Navigation | go_router with shell routes |
| Money | `package:decimal`, P18 S3 |
| Telegram | TDLib via `libtdjson` FFI |

## Building

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.47 or newer.

```bash
git clone https://github.com/0101001001001011/telepos.git
cd telepos
flutter pub get
flutter gen-l10n
```

Then build for your platform:

```bash
flutter build windows --release
flutter build linux   --release
flutter build macos   --release
flutter build ios     --release --no-codesign
flutter build apk     --release
flutter build web     --release -t lib/web/main_web.dart
```

The web build needs its own entry point. `lib/main.dart` is the till root and
pulls in the database, the serial port and TDLib, so dart2js rejects it —
`dart:ffi` is not available in a browser. `lib/web/main_web.dart` binds the same
screens to a **QUIC/WebTransport wire to the till**. The till serves the bundle
over HTTPS, the browser pairs with a one-time code, and every operation crosses
the wire as a named, authorized message — there is no REST on this path at all.
(REST still exists under `lib/transport/rest/`, reached by one service for
exchange with the legacy backend that is being retired. It is not part of the
terminal wire.) See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Platform toolchains: Visual Studio with the "Desktop development with C++"
workload on Windows; `clang cmake ninja-build libgtk-3-dev` on Linux; Xcode on
macOS.

To run it directly: `flutter run -d windows`.

TelePOS also ships as a Linux appliance that boots straight into the kiosk —
an x86 Ubuntu ISO or a Raspberry Pi 5 image, built from
[telepos-os](https://github.com/kvgosu/telepos-os). See
[docs/appliance.md](docs/appliance.md) for how the two halves fit together.

## Configuration

**Telegram credentials.** TelePOS ships without an `api_id`/`api_hash` pair —
this repository is public, and a shared credential would be a shared liability.
Register your own application at [my.telegram.org](https://my.telegram.org),
then either bake it into the build:

```bash
flutter build windows --release \
  --dart-define=TELEGRAM_API_ID=your_id \
  --dart-define=TELEGRAM_API_HASH=your_hash
```

or enter it at runtime in **Settings → Telegram → Telegram application**, where
it is kept in the platform secure store.

**CouchDB.** Configure the server URL and per-organization credentials in the
setup wizard, or in **Settings → Sync**. Do not expose a CouchDB instance to the
internet without TLS.

**Fiscal operator.** Select the provider and enter its keys in
**Settings → Fiscalization**. With no provider configured, TelePOS runs
non-fiscal and prints receipts without fiscal marks.

## Development

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # after schema or freezed changes
flutter test test/e2e/ui_showcase_test.dart --update-goldens   # regenerate the screenshots above
```

End-to-end tests in `test/e2e/` boot the real dependency-injection graph against
an in-memory database, so they exercise actual repositories and use cases rather
than mocks. See [CONTRIBUTING.md](CONTRIBUTING.md) for the layering rules and
the conventions that matter.

## Roadmap

- Repairing synchronization between tills — the largest open piece.
- Making first launch and the setup wizard something an operator can finish
  unaided.
- Expanding fiscal coverage beyond Kazakhstan, with the tax rules validated
  rather than assumed.
- Bringing the data-collection terminal (see below) into the same wire protocol.

The legacy Go backend has been removed; CouchDB and Telegram are the only two
remaining transports between sites, and the browser terminal talks QUIC.

## Related projects

- **[telepos-os](https://github.com/kvgosu/telepos-os)** — a Linux appliance
  that boots straight into the kiosk, as an x86 Ubuntu ISO or a Raspberry Pi 5
  image. Working and in use.
- **Data-collection terminal (TSD)** — a companion Flutter application for
  handheld barcode terminals, aimed at stock counts, receiving and warehouse
  work in the field. It exists as a separate codebase and is **currently
  dormant**; bringing it onto the TelePOS wire protocol is on the roadmap
  above. It is not part of this repository and is not released.

## Contributing

**We do not accept pull requests.** TelePOS is developed by its own team and
code is merged only by that team; patches sent here will be closed unread. The
reasoning is in [CONTRIBUTING.md](CONTRIBUTING.md), and it is about the standard
we would have to vouch for, not about the people offering.

Everything else is open, and it is what we actually need:

- **Bug reports and reproductions** — the most valuable thing you can send.
- **Testing**, especially the paths named in [Project status](#project-status).
- **Questions and criticism** in the issue tracker.
- **Forks.** The AGPL guarantees your right to take this code, change it and run
  it. Nothing here restricts that.

Report security issues privately as described in [SECURITY.md](SECURITY.md), and
note the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[GNU Affero General Public License v3.0 or later](LICENSE) © 2026 Rob Kim

AGPL was chosen deliberately. If you modify TelePOS and let other people use it
— including over a network, as a hosted service or a browser terminal — you must
offer them the source of your modified version. Running it unmodified in your
own shop carries no such obligation, and neither does using it commercially.

The reusable libraries under `packages/rk_*` are published separately on
pub.dev under the **MIT** licence and keep it. They are infrastructure — QUIC,
PKI, mDNS, syslog — with no reason to be copyleft, and MIT is compatible with
AGPL, so the combined application is licensed as a whole under AGPL.
