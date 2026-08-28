# TelePOS architecture

The rules development follows. Short on purpose — if a rule needs a paragraph to
justify, the justification lives in `docs/internal/superpowers/specs/`.

## Layers

```
UI          lib/presentation/    screens, widgets, controllers
                  ↓ depends on
CONTRACT    lib/domain/          interfaces, entities, use cases
                  ↑ implemented by
BACKEND     lib/data/            database, sync
            lib/hardware/        printers, scales, drawers, displays
            lib/telegram/        transport
            lib/backend/         the local API that exposes all of it
```

**Dependencies point inward. Always.**

- UI imports `domain` only. Never `data`, `hardware`, `telegram`, `drift`,
  `dart:io`, or a plugin.
- `domain` is pure Dart. No Flutter, no infrastructure.
- Backend implements `domain` interfaces and knows nothing about widgets.

A UI file that imports `AppDatabase` is a bug, not a shortcut. There are 76 of
them today; they are being removed, and no new ones are accepted.

## One UI, two bindings

The same screens run two ways. The difference is only which implementations the
entry point binds to the contracts:

| Entry point | Binds contracts to | Used by |
| --- | --- | --- |
| `lib/main.dart` | local implementations, in process | desktop till, appliance |
| `lib/web/main_web.dart` | HTTP implementations against the backend | browser terminals, debugging |

Neither entry point owns screens. Both run the same `TelePosApp`. If a screen
exists in one and not the other, the split has been done wrong.

## Hardware

**Hardware lives in the backend. The UI never touches a device.**

The UI asks the contract to print a receipt; whether that reaches a USB port, a
network socket or nothing at all is the backend's business.

**Network printers are the supported configuration for multi-till sites.** A
USB-attached printer serves exactly one till, because a backend cannot reach
across a network into another machine's USB bus. This is a documented
deployment recommendation, not a limitation to work around.

## Terminals

**A terminal is a first-class entity. Settings belong to a terminal, not to an
installation.**

One site can run several tills, each with its own printer, drawer, display and
scales. Anything that reads "the printer address" must read "this terminal's
printer address". Configuration that cannot name a terminal is wrong.

This holds at every size the product must serve: a single till in one shop, and
hundreds of tills across a chain, are the same model with different
configuration.

## The API

**Endpoints are screen-shaped, not table-shaped.**

One call returns what a screen needs. A screen that issues twenty small queries
costs nothing in process and twenty round trips over a network — an API that
mirrors the DAOs works on localhost and crawls on a LAN.

**Every client is identified and capability-scoped.** Not "someone with a
token": cashier terminal 3, the self-service kiosk, an integration. A kiosk may
sell and print; it may not open the drawer or close a shift.

**The API is the integration point.** Self-service, robots and AI clients use
the same surface as the browser. There is no second port to add later.

## Security of the local API

- Loopback only. Binding elsewhere puts a cash drawer on the network.
- Reject any `Origin` that is not the frontend this backend serves.
- Token minted per process, injected into the served document — never compiled
  into the bundle, or every installation would share one credential.
- Hardware operations are POST. A GET can be triggered by an image tag.

## Money

`Decimal`, precision 18, scale 3. Never `double`, in any layer, including over
the wire — serialize as a string, not a JSON number, because JSON numbers are
doubles.

## Debugging

The browser binding exists as much for development as for deployment. It makes
the whole system inspectable: Playwright walks the real screens, the backend
streams its log, and a failure is visible where it happens rather than inferred
from a test that went red.

Keep it that way. Anything that makes the browser binding a second-class path —
screens that only work natively, logs that only reach a file — costs more than
it saves.
