# Changelog

All notable changes to TelePOS are recorded here. The public repository receives
source snapshots, not the development history, so entries are grouped by
snapshot date rather than by commit.

## Guides

Video guides for TelePOS are published as they are recorded:

- YouTube — https://www.youtube.com/@BobKim-xz5fy
- Telegram — https://t.me/sphere_x_bot

## 3.7.2 — 2026-09-24

The installer now speaks all five languages the till speaks, and picks the
right one by itself.

### Five languages, chosen by Windows

- **English, Russian, Kazakh, Kyrgyz and Uzbek.** The package carries an
  English base and an embedded transform per language, and declares all five
  codes; Windows applies the one that matches the system.
- Kyrgyz and Uzbek have no translation in the WiX toolset, so they were
  written for this project — 205 strings each, exactly the ones the installer
  dialogs reference. Uzbek is in the Latin script, matching the till's own
  dictionary: two scripts in a row from one product look like two different
  products.
- Kazakh needed nothing written: WiX ships it.

  *Correcting 3.7.1's notes:* they said WiX ships no translation for any of
  the three. That was wrong and unchecked — the sort of claim about the world
  that should be measured rather than assumed. The 3.7.1 notes now carry the
  correction.

- The licence screen opens with a preamble in the language of the installer —
  the product, who holds its copyright, what you may do in plain words, where
  the source is, and that this is an alpha — in all five. Without it the three
  new languages would have quietly shown an English preamble above an English
  licence: you would lose your language on the one screen where it matters.
  The binding text of the GNU AGPL stays English, and the preamble says why.

### What this release does not change

Nothing in the till itself. Database schema v58, same as 3.7.0 and 3.7.1.
If you have 3.7.1 installed and read English, there is nothing here for you.

### Notes

- Alpha. No shop is running this in production yet — we are looking for QA.

## 3.7.1 — 2026-09-24

A correcting release, hours after 3.7.0. Most of it is the installer, which
turned out to be speaking Russian to the whole world, and a licence screen
that never named the product you were about to install.

### The installer now speaks the language of the machine

- **The MSI is multilingual and Windows picks the language.** It used to be
  built with a single culture and with the product language hard-wired, so
  the stock dialogs — Next, Install, I accept — were **Russian on every
  machine in the world**, including an American one, while the licence next
  to them was always English. The package now carries an English base and an
  embedded Russian transform, and declares both language codes; Windows
  applies the right one.
- English is the base on purpose: the base is what a person sees when their
  own language is not in the list.
- Kazakh, Kyrgyz and Uzbek are **not** in this build; those systems get
  English. They are in the next one.

  *Correction, added after release:* the reason first given here — "WiX ships
  no UI translation for them" — was wrong and had not been checked. WiX does
  ship Kazakh. It does not ship Kyrgyz or Uzbek, and those two now have
  translations written for this project.
- The shortcut tooltip, the package description, the entry in Programs and
  Features and two refusal messages ("64-bit Windows only", "a silent
  install cannot ask for administrator rights") were Russian on every
  install. They are not any more.

### The licence screen says what you are accepting

The agreement used to be the bare text from the Free Software Foundation,
opening with *Copyright (C) 2007 Free Software Foundation* — you clicked "I
accept" under a document that never once named the product being installed,
or who holds its copyright.

It now opens with a short preamble in the language of the installer: the
product, the copyright holder, what you may do in plain words, where the
source is, and that this is an alpha. The binding text of the GNU AGPL
follows, **in English**, because the Free Software Foundation does not
recognise translations of it as official — and the preamble says exactly
that rather than leaving you to assume.

### Corrections in the till

- **The till now tells you where its data lives.** No screen did: not
  diagnostics (those are about devices), not system management. For a till
  that has to be backed up and one day moved to another machine, that was a
  fair question with no answer anywhere in the product. Settings → General
  now lists the database, the logs and the backups, and copies a path on a
  click. Read-only on purpose: a "change folder" button would one day move a
  database out from under an open shift.
- **The version the till reported was one release behind.** It lived in
  three places and the release script knew two of them, so 3.7.0 introduced
  itself as 3.6.0 — exactly as 3.5.1 had introduced itself as 3.5.0. There
  is one literal now, in the place the script edits.
- **669 dictionary keys that nothing asked for** were removed, across all
  five languages. A dead key is worse than a missing one: the dictionary
  claims a screen is translated when it is not. That is how the expense
  kinds came to have two competing key sets, one of them unused.

### Notes

- Database schema v58, unchanged from 3.7.0.
- Alpha. No shop is running this in production yet — we are looking for QA.

## 3.7.0 — 2026-09-23

This release makes the till **usable outside Kazakhstan**. Tax became a
configured engine instead of a number in the source, the interface and the
paper stopped speaking Russian on a non-Russian till, and the shift's money
was reduced to a single identity that the screen, the ledger and the Z-report
all agree on.

Most of what is listed here was found by **filming the video guides on an
American till**, not by the test suite. A dry run puts the product in front of
a camera in a language and a country it had never actually run in, and that
turns out to be a measuring instrument the suite is not.

### Tax: configured, not compiled

- **Tax rates left the source code.** `CountryCode.vatRate` is gone. Rates live
  in `assets/tax_presets/*.json` — 19 sets, one per country plus a city-level
  set for the United States — and the setup wizard applies the country's set
  once; after that the till lives by its own configuration. Rates are written
  as strings, never as JSON numbers.
- **A rate is derived, not stored**: jurisdiction + product category + date.
  A jurisdiction set (country → state → county → city) stacks, a category can
  be exempt in one jurisdiction and taxed in another, and every rate carries
  the date it takes effect.
- **Tax on top of the price** (United States) versus **tax inside the price**
  (CIS VAT) are both first-class, and a receipt shows the rate breakdown under
  each rate rather than one line for the whole receipt.
- The VAT formula existed in **six** places and they had drifted; one of them
  had been folded into `4/29` and was hard-wired to 16 % on the live receipt
  printing path. There is one home now, and a guard that looks for the
  *declaration*, not the spelling — a folded formula leaves no trace to grep.
- Seller address reaches the receipt **in every country**. Until now the wizard
  collected it and only Kazakh fiscalisation wrote it, so an American receipt
  never carried it at all. It is also editable: a shop that moves no longer
  needs a reinstall.
- Receipt dates follow the country, not the CIS order.

### Language

- The interface, the paper and the customer display now follow the till's
  language. Previously: 54 hardcoded Russian strings across 13 screens, then
  another 88 the first guard could not see, then 26 more in states it never
  reached — including "X-report" and "Correction receipt" on the shift screen.
- **Printed documents** (receipt, X-report, Z-report, cash-operation slip) are
  assembled in the till's language. Before this, every line on paper was a
  Russian literal regardless of the setting.
- **The customer display** — the screen the *buyer* reads — said "Цена:",
  "ИТОГО:", "Сдача:" on every till in the world.
- Words that a person reads no longer live outside the dictionary: role names,
  permission labels, device catalogue entries, expense kinds. A guard enforces
  it, and it covers `core/`, `data/`, `hardware/` and `telegram/` — the layers
  where the previous guard did not look.
- **The expense kind got a column** (`cash_operations.reason_code`). It used to
  be glued into the note as prose — `"Зарплата: for August"` — which cannot be
  translated after the fact and cannot be summed: "how much went on wages this
  month" would have meant parsing Russian text.
- 52 hardcoded tenge signs across the screens; the currency symbol now comes
  from the till, and currency was removed from the dictionary entirely.
- Banknote denominations come from the country. An American cashier was
  counting notes that do not exist and could not count a dollar, a five or a
  twenty.

### The shift's money is one number

The panel labelled *Expected in register* showed `0.00` with $200 in the
drawer. Behind it were six defects in one model, each of them individually
green across 6 000+ tests:

- the opening count was written to the shift row and **nowhere else**, so the
  till's own ledger never saw it;
- a cash deposit entered the expectation through **no term at all** — paying
  100 into the drawer produced a 100 overage at close;
- the close reconciliation wrote its journal row without moving the balance, so
  the journal and the ledger parted permanently;
- a close without a recount recorded the ledger while the screen compared
  against the expectation;
- the Z-report was never handed this shift's opening float and printed the
  **previous** shift's closing count;
- the screens showed a discrepancy computed from the ledger while the till
  recorded one computed from the expectation — a cashier who counted the
  drawer correctly would have seen a $200 overage.

There is one identity now, and the POS account balance, the shift expectation
and the `TOTAL IN DRAWER` line of the Z-report all equal it at every moment of
a shift. A difference between a hand count and the ledger is posted as a
visible cash operation of its own kind, never absorbed and never typed as a
deposit or a withdrawal.

### Other corrections worth naming

- **A product with no price was given away for free**, on both paths including
  the scanner. It hid behind 36 registered-and-never-asked contracts — 4 376
  lines of code that looked live, including a `SaleValidationService` that
  created the impression prices were checked.
- **Selling-hours restrictions** (alcohol at night and the like) were declared
  and did nothing: the table, the DAO and the use case had existed from the
  start, nobody called them, and there was no screen to fill them in. Inside
  the DAO, a query that accounted for the parent category threw its own result
  away. Implemented end to end, with a `/selling-hours` screen.
- **The receipt ceiling** was hard-wired to one million (≈$2 000), so an
  American till had no protection at all. It is a setting now.
- **A per-role discount limit did not apply on browser terminals.** The session
  was minted with the *display word* for the role while the wire matched it
  against the stable key, so the match never succeeded and only the "any role"
  limit was ever found.
- National systems (ESF, SNT, ESUTD, IS MPT) and the Kazakh tax tab were shown
  on every country's till; they follow the country now. Nine countries declared
  fiscalisation while only two had an operator.

### Notes

- Database schema v58. Migration from any released version is tested, including
  the timing and integrity checks.
- Alpha. No production deployments yet — we are looking for QA.

## 3.6.0 — 2026-09-19

The till can now sell completely from a **browser terminal** (a tablet or
phone on the shop network), the payment side of a sale was rebuilt around a
catalogue of payment kinds, and the remaining gaps found by live acceptance
were closed: certificates and prepayment in the fiscal receipt, discounts from
the terminal, refunds by payment kind, receipt width and template.

### Selling from a browser terminal
- Sale screen in the browser: the till owns the cart, receipt number and shift;
  the terminal shows the receipt and sends commands over QUIC WebTransport.
  One command in flight, retries reuse the same idempotency key.
- A receipt in progress is visible only to its workplace; parked (deferred)
  receipts go to a shared pool and name their owner when picked up.
- Refunds from the browser terminal against the original receipt.
- Payment from the browser terminal. Fiscalisation, receipt printing and the
  cash drawer are executed by the till on the terminal's command.
- One person per workplace at a time; after a page reload the tab names its
  workplace again; an expired session leads back to login with the reason.
- Each workplace has its own set of allowed payment kinds.

### Payments
- **Payment kinds catalogue** (cash, card, bonus, debt, certificate, QR/SBP,
  prepayment, installment) with a fiscal treatment per kind that the operator
  can change in settings; disabled kinds are disabled for the till as well.
- **Sale on credit (debt)** gets its own payment line and permission check.
- **Installment with a credit agreement** and a payment schedule
  (equal, decreasing, markup on the first payment).
- **Gift certificates**: issue, redeem with optional PIN, expiry, balance kept
  on the certificate (no change given), several certificates on one receipt.
  Repeated failed checks are locked per certificate, per cashier and per
  terminal (5 / 10 / 10 failures within 15 minutes).
- **Customer prepayment (advance)**: the available balance is shown before
  entry and is set off against the receipt; refunds return it as an advance,
  not as cash from the drawer.
- **QR / SBP payments** through a payment provider configured on the till.
  The provider key never leaves the till. Waiting blocks other payment,
  cancellation is confirmed with the provider, and money that arrives before
  the cancellation is applied to the receipt exactly once; money that arrives
  after the receipt is closed is shown on a "money without a receipt" screen.
- Offsets are applied in one fixed order (bonus → QR → certificate →
  prepayment) by the till and by the payment screen preview alike.

### Certificates and prepayment in the fiscal receipt
- Redeeming a certificate and setting off a prepayment are **no longer reported
  as cash**: paying with a certificate is not a cash settlement, so the
  operator's cash total matched the drawer only by accident before.
- Three settings on the till (fiscal settings screen): fiscalise the **sale** of
  a certificate (off by default), the layout of an offset in the receipt
  (as a discount, or a receipt for the top-up only), and a **fiscal receipt when
  a prepayment is received** (on by default; the means of payment is recorded).
- **Paying a prepayment back in money** is a real operation now, with its own
  fiscal document (a return receipt) instead of a cash withdrawal: it takes the
  money off the customer's account, out of the till account it was received
  into, and reports it to the operator by the means of payment used. It obeys
  the same setting as taking a prepayment in, so a till that does not fiscalise
  the intake does not fiscalise the payout either.
- Local records of fiscal documents are keyed by **document kind and number**,
  not by number alone. A sale, a refund and a prepayment number their documents
  from three different sequences that all start at one, so records used to
  overwrite each other silently on a fresh till.
- Returning goods paid for with a certificate **issues a new certificate** for
  that amount; the old one stays spent and is never revived. Returning the
  purchase of a certificate **voids it in the same transaction** — before, the
  till handed back cash and left the certificate usable. A certificate cannot
  be refunded in cash, and cannot pay for another certificate.
- QR / SBP now reaches the operator as a **mobile payment**, not as a card.
- A **gift certificate slip** is printed when a certificate is issued and when a
  new one is issued on a refund: number, amount, expiry, the link to the refund,
  marked as a non-fiscal document. The PIN is never printed. If there is no
  printer, the issue and the refund still go through and the cashier is told the
  slip did not print.

### Refunds
- Money goes back **the way it came**: debt, bonus, certificate, prepayment,
  cashless, cash — in that order for a partial refund. Card and QR are returned
  through the terminal and the provider before anything is written, and the till
  never hands out cash in place of a cashless refund.
- The refund screen shows where the money will go before the cashier confirms.

### Receipt printing
- **A narrow receipt was printed even when a wide one was chosen.** The width
  was saved on the printer screen but no receipt builder read it: the template
  kept its own width from the setup wizard, X/Z reports used a hard-coded 32
  columns. The width now comes from the printer binding on every print, with no
  restart.
- The template header and footer are free multi-line text with alignment, bold
  and double size, wrapped to the chosen width. The preview is rendered from the
  same bytes that go to the printer. A template can no longer switch off the QR
  code, the BIN/IIN or VAT on a fiscal receipt.
- **Kazakh letters and the tenge sign used to print as "?".** No ESC/POS code
  page contains ә, ғ, қ, ң, ө, ұ, ү, һ, and none exists for Kazakh at all, so
  the receipt now prints them with their Russian base letter (Сүт → Сут) and
  the tenge sign as "тг". This is a degradation, not an equivalence, and it is
  visible before printing: the on-screen preview is built from the same bytes
  by the same table. The fiscal document is unaffected — it travels to the
  operator as UTF-8. The same applies to EPL labels and to the customer
  display; ZPL and TSPL labels are left alone because they carry UTF-8.
- One character table for paper, for both encoding and decoding. There used to
  be eight and they disagreed: one encoder turned the tenge sign into a Latin
  "T", the emulator read byte 0xFC as "·" where the till writes "№", and the
  customer display sent lowercase "р"…"я" into the box-drawing range, so the
  shopper saw frames instead of letters.

### Loyalty and discounts
- Bonus account movements are kept as a journal: an accrual is reversed on
  refund and bonuses are no longer written off twice.
- Discount limits with an audit of attempts; the discount dialog shows the
  limit before input; percentage discounts are supported.
- A promotion's gift item is named on the receipt.

### Fiscalisation
- **Receipts with Cyrillic item names now reach WebKassa.** The request body
  was written as Latin-1 and was rejected before sending; it is now UTF-8.
- A request that cannot be built is recorded as failed with a reason instead
  of waiting in the offline queue forever.
- Discounts and bonuses reach the operator correctly; tax rounding no longer
  loses a tiyn per line.
- One screen for receipts without a fiscal document, with the reason, and a
  count at shift close.
- **A sale's idempotency key now survives the cleanup of old sales.** Receipt
  numbers restart once the `Sales` table is swept (7 days online, 90 offline),
  so the old `sale-<receipt>-<till>` key came back to the operator already
  taken and every new sale was answered with code 14 — money taken, no fiscal
  document. The key now carries the sale's own timestamp, which the sweep
  cannot repeat: it only deletes rows older than the cutoff. Documents already
  queued keep the key stored with their row, so the change cannot register a
  second document for the same receipt.
- **The Z report no longer overtakes the documents of its own shift.** Closing
  a shift now waits for one delivery pass of the fiscal queue first; if
  documents are still undelivered, the Z report is withheld with a named
  reason and the till shift is closed anyway. Sending it first would have
  pushed those receipts into the operator's next shift — yesterday's takings
  in today's report, with nothing to detect it.
- **Code 14 in the queue no longer counts as settled.** "A document with this
  ExternalCheckNumber is already registered" means the operator has the
  document while the till never received its fiscal sign, and the protocol has
  no way to ask for it by key. The queue row is now kept with a named reason
  for a person to resolve instead of being silently removed.

- **A receipt paid partly by card and partly by a gift certificate now
  reaches the operator.** With selective fiscalisation ("cashless receipts
  only") the till asked every payment line "is this cashless?", and a
  certificate redemption — which is not a payment at all — carried the whole
  receipt past the operator: money taken by card, no fiscal document, and
  nothing said to the cashier. The question is now asked of the receipt as a
  whole: it goes to the operator when it has a cashless line and no cash one.
  The same silence hit bonus and debt lines.
- **A refund line whose payment kind the till cannot name no longer turns
  into cash.** A kind written on a receipt from another till is refused by
  name before any money moves; a pre-v41 line with no kind at all keeps
  working and is reported to the operator by the route the money actually
  took (drawer — cash, bonus account — bonus), so the drawer and the fiscal
  document no longer disagree.

### Errors shown to the cashier
- Every refusal code the till can send (127 codes) reaches the cashier as a
  translated phrase instead of an internal code; a lost connection and an
  expired session are named as such.
- Refusals on the payment screen are shown inside the payment card.

### Honesty of the till
- The age of a shift is checked by the till itself, and the browser gets a
  named reason instead of a dead route.
- A missing cash drawer or a broken payment-terminal binding is **named**
  instead of passing for success; a guard keeps that shape from coming back.
- Rights for editing a price, wholesale mode and parking a receipt are checked
  by the till's cart, not only over the wire.
- The shift badge has a third state, "unknown", instead of defaulting to
  "closed".
- The certificate brute-force lock now works on the till as well and counts
  **per cashier** (a cashier's shift is their own); a lock is written to the
  security journal.

### Browser terminal
- Discounts can be entered from the terminal: the till checks the right and the
  limit, and the limit is shown before input.
- Quick products and scanner rules come over the wire; the "Deferred" button
  follows the cashier's right; stock on screen refreshes after a sale.
- After the till is updated the browser gets the new bundle instead of a cached
  one.

### Fixes
- A barcode scanner no longer receives keystrokes typed into a dialog opened
  over the sale screen.
- Two concurrent completions of one receipt could take the money twice; the
  receipt is now claimed before payment.
- Taking a customer prepayment from the browser terminal could take the money
  twice: the wire dropped after the till had accepted it, the tab showed a
  refusal, and pressing again recorded a second payment. Each request now
  carries a repeat key, stored in the same transaction as the money; a repeat
  answers with the previous outcome instead of taking anything.
- The pay button could reject the first press as a double press.
- Many smaller fixes on tablet layouts, refunds and the login screen.

### Hardware diagnostics
A new screen answers the one question a technician asks first — **what did the
till actually send to the device?**

- **Receipt printer**: the print queue with the state and refusal reason of
  every job, and the receipt itself rendered from the very bytes that went into
  the port — not from a second layout, which this project has been burned by
  before.
- **Cash drawer**: the till now remembers the pulses it sent. It says *command
  accepted*, never *drawer opened*: neither path reports back from the solenoid,
  and the screen says so in as many words.
- **Scales**: the live reading, at the resolution the device sent it. When no
  scales are bound the screen says that, because an empty field on a till
  without scales is indistinguishable from scales with a cut cable.
- **Customer display**: the lines the till sent, with the same caveat — a dark
  or unplugged display is indistinguishable from a working one here.
- **Fiscalisation**: the queue with the idempotency key, attempts and the
  verbatim last error, and the documents the operator accepted.
- A banner marks a device whose binding points at **this same computer**, so a
  receipt parsed in an emulator window is never mistaken for one that came out
  on paper. It is driven by the binding address, not by a switch: an emulator
  started by hand from the command line is marked the same way.

### Emulators built into the till
External dependencies are emulated so the product can be exercised without
hardware or contracts: WebKassa, SBP/QR provider, ESC/POS printer, label
printer, cash drawer, scales, customer display, Kaspi terminal.

Since this snapshot the emulators **ship inside the application** and are
switched on in settings — nothing else to install. The till opens a real server
socket (printer) or a real port file (scales, customer display) and reaches it
through its own drivers, over its own frames, at the address written in the
device binding. Nothing is substituted in the dependency container: were a fake
driver put there, "it works on the emulator" would stop saying anything about
working on metal.

Turning an emulator off stops it but does **not** silently rewrite the device
binding: a till left pointing at a stopped emulator must honestly say the device
does not answer, and the settings screen says why.

### Data and tests
- Database schema v36 → v53, tables 91 → 105 (payment kinds, bonus
  journal, discount limits, certificates, payment intents, installment
  agreements, QR provider settings, fiscal settings for offsets, links between
  a re-issued certificate and its refund, a Z report the till still owes, and
  the till's memory of prepayments already paid out). Existing databases
  migrate on start.
- **Upgrading a real till no longer takes a minute of black screen.** The
  v28 → v53 ladder was measured on a realistic volume rather than estimated:
  **64 s → 0.9 s**. Every rung is now exercised, not a sample of them.
- Test declarations 3572 → 5836.

### Money that used to go quiet
Four defects found by measuring the plan against the code rather than reading
it. Each took money and said nothing.

- **A receipt paid partly by card and partly by a bonus or a debt line** now
  reaches the operator too — the same silence as the certificate case above,
  found in the same place.
- **Handing a prepayment back in cash** had no path at all: taking one issued a
  fiscal receipt, giving it back did not, and the only way to release the money
  was a service expense that never touched the customer's account. The path now
  exists and follows the same setting as the intake.
- **The Z report no longer overtakes the documents of its own shift.** A receipt
  queued in the last minutes of a shift reached the operator *after* the Z
  report — and, because the operator opens a shift implicitly with the first
  document, yesterday's takings landed in today's report. Nothing on either side
  noticed.
- **A duplicate answer (code 14) is no longer swallowed.** There is no way to
  ask the operator for the fiscal mark afterwards — nine endpoints were checked
  — so the queue row is now kept for a human instead of being deleted as a
  duplicate.
- **The fiscal document table could overwrite its own rows.** Its key was the
  operation number alone, and three different sequences write into it (receipt,
  refund, cash operation), all starting at one on a new till. Schema v50 makes
  the key a pair with the kind of document.
- **A QR payment that had been refunded still read as paid.** The refund asked
  the provider for the money back and told the till's own record of the payment
  nothing at all, so start-up reconciliation, the QR diagnostics tab and the
  receipt's payment state all still saw money that was no longer there. Schema
  v51 records how much came back and when; the payment is marked reversed only
  once all of it has.

### What the cashier can finally reach
- **Issuing a gift certificate** has a screen. Until now the operation existed
  on the wire, was guarded by its own permission and covered by tests — and no
  screen called it on either build. The slip can be reprinted from the same
  screen when the printer was busy or missing.
- **Paying a prepayment back in money** has a screen too, next to taking one in,
  in the customer's card.
- Issuing a certificate is deliberately **not** folded into the payment step:
  a refusal there (a taken number is one typo away) would land after the money,
  on a screen that already said "done". The wire keeps the same boundary.

### Kazakh letters and the tenge sign on paper
Everything outside {ASCII, Russian, №} used to print as `?`: Kazakh letters
(ә ғ қ ң ө ұ ү һ), the tenge sign ₸, and quotation marks.

- One character table now serves the receipt, the label, the customer display,
  the test print and both emulators. There were **eight** encoders before,
  disagreeing with each other — one turned ₸ into a Latin `T`.
- **Kazakh letters are replaced with their Russian base** (`Сүт` → `Сут`). No
  ESC/POS code page carries the Kazakh alphabet; the choice was between refusing
  to print a receipt for a product with a Kazakh name and printing a degraded
  one. This is a degradation, not a match — the preview shows exactly what the
  paper will show, so it is visible before printing.
- **₸ prints as `тг`**, not as a lookalike letter.
- Found on the way: the customer display was sending lowercase Cyrillic into the
  box-drawing range — shoppers saw frames instead of letters.

### Hardware the tablet can finally see
- **The cash drawer, the scales and the customer display reach the browser
  terminal** over the same wire as everything else: a port on the till, its own
  operations, and the diagnostics tabs on top of it. The tablet had two tabs;
  it now has five.
- The drawer tab says **"command accepted"**, never "drawer open": there is no
  feedback from the solenoid on either path, and the comfortable wording sends
  the fitter looking for a fault in the till instead of in the wiring.
- "No record of the pulses" and "the drawer was never opened" are **different
  answers**. So are "the scales are not bound" and "the scales have said
  nothing yet".
- Scale readings arrive as a ready three-decimal string prepared by the till:
  `Decimal` prints 1.250 as "1.25", and a tab formatting it itself would have
  dropped grams silently.

### Found by running the tablet against a real till
Three defects that only the browser build had, each hidden behind the one
before it.

- **A refusal from the till no longer looks like waiting.** Every diagnostics
  tab showed a spinner whenever it had no data — a condition that is true both
  before the first frame arrives and after it never will. The fitter read the
  spinner as "any moment now" and waited. Refusals are now named, with the
  till's own reason.
- **A subscription that ends legitimately no longer arrives as a broken link.**
  Asked about hardware that is not connected, the till answers with one value
  and closes the stream on purpose — "there is no such device here", a final
  answer. The browser treated every quiet close as a broken session, so the
  named answer never reached the tablet at all. The till now sends a `done`
  frame before closing; silence still means a broken link.
- **The receipt preview lied about the paper.** The printer tab shows the
  receipt as text decoded from the same bytes that went to the port, so that
  columns and wrapping can be checked before printing. Fifteen places asked for
  a font family named `monospace`, which the app does not bundle: on the till
  the system supplies one, in a browser nothing does, and the receipt was drawn
  in a proportional face — a 48-dash rule came out shorter than a 48-character
  line. A guard now checks every font family named in code against the ones
  `pubspec.yaml` declares; it immediately found a second invented family
  (`Arial`, used for label and table rendering), which on a Linux appliance
  would have silently shifted label layout.

### Fiscal documents that hold on to their own basis
- **A refund now holds on to the document it refunds**, by key, rather than to
  whichever queued row happened to match. The envelope names that key.
- **A Z report delayed by a dead link is sent when the next shift opens.**
  Before, it waited for a queue that had already moved on.
- **X/Z selection by cashier became strict** — and that is measured, not
  assumed.
- **Issuing a certificate asks for the permission itself**, as a required
  argument, on both fronts: the cashier's screen and the wire. Forgetting it is
  now a compile error rather than a silent grant. Ninety-eight call sites were
  changed to carry it.

### Prepayment and slips from the tablet
- **Paying a prepayment back** goes over the wire, recognises a repeat by an
  intake key issued before the frame leaves (not after it arrives), and the
  till remembers what it has already paid out.
- **A certificate slip can be reprinted from the tablet.** The till prints on
  command; the tablet never touches the port. This is the operation a cashier
  actually needs — the slip at issue time always printed, the repeat was
  unreachable.
- A refund line pointing at a certificate with no number is **refused before
  the money moves**, not after.
- Editing a price (the wholesale path) is closed by a till setting on both
  entries, not one.

### Known limitations
- The exact receipt layout for certificates and prepayment follows Kazakhstan
  practice and the tax authority's clarifications, but has not been confirmed
  with a fiscal operator; the defaults are settings and can be changed.
- QR / SBP is exercised against an emulator only — no real provider contract
  has been tested.
- Label printers using EPL print Kazakh letters and the tenge sign as "?"; the
  Kaspi terminal's reply encoding is an assumption.
- Refunds of QR payments made before schema v51 carry no record of how much came
  back: there was nothing to derive it from, and an invented figure would have
  been indistinguishable from a real one.
- Nothing has ever been measured on a real XPrinter: the code-page selection
  (`ESC t 17`), how "тг" reads in an amount column on 58 mm paper, and whether
  an EPL label printer renders Cyrillic in the font our templates request are
  all open until hardware is available. The Kaspi terminal's reply encoding is
  an assumption.
- Kazakh, Kyrgyz and Uzbek translations of new messages need a native speaker.
- Only Kazakhstan has been exercised; synchronisation between several tills
  remains broken (see Project status in the README).
