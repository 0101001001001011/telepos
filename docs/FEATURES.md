# TelePOS — capability catalogue

A list without detail: what is in the product, in blocks. Compiled by walking
the code — tables, use cases, screens and routes (76 routes, 91 tables, schema
v36, 4 operating modes). Last reconciled 2026-08-28.

The final section, **"Not in the code"**, exists so that this list cannot pass
intention off as delivery. Read it. It is the honest half.

Operating modes: **retail · restaurant · service · warehouse**.
Workstation roles: **cashier · self-service · unattended · kitchen**.

---

## 1. Trade — till and selling

- Retail sale, receipt with lines
- Product search by name, code, barcode
- Search by product alias
- Search by marking code
- Quick products (fast-access tiles)
- Open product (free price)
- Kits and sets (composite products)
- Product components
- Weighted goods, weight taken from the scale
- Piece, weight and draught accounting by unit of measure
- Changing quantity and price on a line
- Removing a line; voiding a line while keeping the trace
- Deferred receipt and returning to it
- Partial withdrawal from a receipt
- Sale block by category
- Sale block by product
- Refusal to sell below the till's price floor
- Total rounding by the site's rules
- Extra receipt fields (arbitrary attributes)
- Attaching a customer to a receipt
- Credit sale with a limit
- Receipt printing, reprint of the last receipt
- Non-fiscal receipt when no operator is selected

## 2. Payment

- Cash with change calculation
- Card payment
- Mixed payment across several methods
- Payment with bonus points
- Payment on credit (accounts receivable)
- Payment through Kaspi POS
- Payment terminal as a workstation device
- Storage of authorisation code, card mask and transaction number
- Denomination hints when taking cash
- Sufficiency check before completion
- Refusal to combine bonus points with credit
- Customer debt repayment
- Customer prepayment
- Purchase for cash (cash paid out of the till)

## 3. Refunds

- Refund against a sale receipt
- Partial refund by line
- Refund eligibility check
- Bonus refund and reversal of accruals
- Refund of payments by payment method
- Refund of marked goods with their codes
- Refund receipt with separate numbering
- Rounding rules in a refund

## 4. Discounts, bonuses, loyalty

- Line discount as before/after price (`price` / `priceBefore`)
- Discount rounding by a configurable rule
- "Sold at a discount" flag
- Markups by category and store (markup table)
- Promotions as condition → reward: trigger product, quantity, reward
- Supplier-funded promotions
- Enabling and disabling a promotion
- Customer bonus (cashback) account
- Bonus accrual from a sale
- Bonus redemption as payment
- Bonus balance by phone number
- Reversal of a bonus transaction
- Bonus refund when goods are returned
- Customer accounts: primary and cashback

## 5. Shift and till money

- Opening and closing a shift
- Opening float
- X-report
- Z-report
- Cash in
- Cash out
- Cash collection as a transfer between accounts
- Expenses by type: other, purchasing, wages, utilities, collection
- Investments and dividends as till operations
- Cash operation receipt
- Arbitrary fields on a cash operation
- Shift history
- Payment-method summary for a shift
- Shortage and overage at closing
- Shift durability when the database is copied (WAL checkpoint)

## 6. Catalog and prices

- Product card: name, category, unit, barcode
- Categories and the category tree
- Category restrictions
- Several prices per product (price editions)
- Product card editions
- Product aliases
- Barcode reservation
- Global product reference
- Fiscal product fields: VAT rate, NTIN, marked-goods flag
- Markup on receipt of goods
- Loss norms by GOST
- Photographs of dishes and products
- Quick products and their order
- Packaged products

## 7. Stock and goods movement

- Goods receipt (supply)
- Supply lines, supply prices
- Supply history
- Write-off with a reason
- Movement between warehouses
- Movement lines
- Return to supplier
- Stocktaking and the count sheet
- Stocktaking discrepancies
- Stock registry
- Replenishment rules (minimum stock)
- Reorder signal
- Purchase order to a supplier
- Cost of goods sold (COGS)

## 8. WMS — addressed warehouse

- Warehouses and their settings
- Warehouse zones
- Storage cells
- Stock by cell
- Put-away into a cell
- Picking from a cell
- Movement between cells
- Batches (number, expiry, certificate)
- Expiry accounting, FEFO picking
- Serial numbers
- Serial number movement
- Serial number statuses
- Claims and their history
- Product quality statuses
- Storage types
- Enabling WMS subsystems individually

## 9. Marking and traceability

- Marking codes on a sale receipt
- Marking codes on a refund
- Marking codes on a service order
- Marking code store
- Marking code statuses
- Marking lifecycle
- Marking verification with the operator
- Withdrawal from circulation through a fiscal receipt
- Marked-goods flag in the catalog

## 10. Fiscalization (Kazakhstan)

- WebKassa as fiscal operator
- Token authorisation, offline document queue
- Fiscal sign, QR and receipt link
- Offline window and later submission
- Fiscalization gated by the selected operator
- Fiscal attributes on a receipt
- VAT calculation, rate per line
- Correction receipt as its own screen
- Fiscal document queue
- ESF — settings, outbound queue, submission
- SNT — settings and documents
- IS MPT — settings and marking verification
- ESUTD — screen and settings
- Fiscal error journal
- Storage of WebKassa receipts
- Configurable volume of OFD synchronisation

## 11. Restaurants

- Table map
- Floor zones
- Table statuses
- Order on a table
- Adding lines to an order
- Dish modifiers, modifier groups
- Technical cards (dish ingredients)
- Recipe versions
- Ingredient write-off when a dish is sold
- Splitting a bill between guests
- Separate bills per guest
- Moving an order to another table
- Merging tables
- Service charge
- Closing a table and printing a pre-bill
- Tips
- Open orders and their list
- Restaurant mode settings

## 12. Service (jobs and repair)

- Repair intake (service order)
- Catalog of services and job types
- Service order queue
- Order card and status transitions
- Photographs attached to an order
- Consumables on an order
- Marking codes on a service order and their approval
- Link between a service order and a sale
- Warranty records
- Release and closing of an order
- Receipt for a service order

## 13. Counterparties and customers

- Customers and suppliers in one reference with a type
- Legal attributes: BIN/IIN, type, addresses
- Search by phone
- Search by string
- Local contacts of a counterparty
- Counterparty accounts: primary and bonus
- Balance and debt
- Online ordering from a supplier: address, key, minimum amount, delivery days
- Restoring a deleted counterparty

## 14. Reports and analytics

- Metrics dashboard
- Sales report
- Product report
- Financial report
- Customer report
- Supplier report
- Forecasts
- Restaurant report
- Kazakhstan report block
- Shift, daily, stock and cash-movement reports from the Telegram subsystem

## 15. Hardware

- Receipt printers: USB, network, Bluetooth, Linux
- Additional printers (kitchen, bar)
- Label printers
- Label templates, ZPL upload
- Receipt templates
- Cash drawer, including through the printer
- Scales, port and baud rate
- Barcode scanners
- Customer display (second window)
- Payment terminal
- Kaspi POS
- Discovery of connected devices
- Device check that names the reason for failure
- Binding a device to a workstation
- Print job queue and print confirmations
- Printing never delays payment

## 16. Workstations and terminals

- Terminal as an entity with its own set of devices
- Roles: cashier, self-service, unattended, kitchen
- Host capabilities determined by how it was launched
- Browser terminal on a separate device
- Till discovery over mDNS
- Terminal enrolment by one-time code
- Terminal service settings
- Listen scope (loopback or network) as the owner's decision

## 17. Users, roles and permissions

- Till users
- Roles: owner, administrator, user, cashier
- Permissions per navigation section
- Permissions per operation
- Permissions per settings section
- Per-user personal settings on the till
- PIN login, PBKDF2 with salt
- User management
- Permissions are an allow-list: an empty table grants nothing
- Attempt lock keyed on the user, with the terminal as a second key
- Live sessions with revocation, and a session watch that survives a link drop

## 18. Telegram subsystem

- Data transport over Telegram
- Application authorisation with your own api_id/api_hash pair
- Channels for exchange
- Bots and bot commands
- Command routing, webhooks
- Automatic creation of channels and groups
- Automatic configuration and its distribution
- Backups over Telegram
- Encryption of transmitted data
- Internal staff chat
- Notifications
- Monitoring
- Reports in Telegram
- Integration bridges: 1C, ERP, server, multi-till

## 19. Synchronization and exchange

- CouchDB as the transport between tills
- Document push, reference data pull
- Sync state and the sync screen
- Mapping documents to the exchange format
- Discrepancy analysers
- Telegram as a second transport

## 20. Network, transport and security

- QUIC WebTransport between till and terminal
- A wire contract of 31 named operations
- Subscriptions: the till pushes changes itself
- Message framing
- Web bundle served over HTTPS
- The till's own root certificate authority
- Certificates issued for a name and for an address
- One-time release of the root against an enrolment code
- Installing and removing system trust for the root
- IPv4/IPv6 dual stack
- Network and transport settings in the interface
- RFC 5424 journalling (`rk_syslog`)
- Every wire operation declares its own authorisation requirement, checked at
  one choke point before the handler runs
- Secrets never leave the till as text on a refusal path

## 21. First launch and setup

- Eleven-step first-run wizard
- Country selection
- Organisation details
- Site operating mode
- Till details
- VAT rate
- Fiscal operator
- Payment terminal
- Hardware
- Staff
- Business rules
- Settings verification
- Summary and completion
- Restore from a backup, or a fresh installation
- "Settings unreadable" as a named state with its own screen

## 22. Platform, maintenance, appliance OS

- Windows, Linux, Android, iOS, macOS, web
- Windows installer (MSI) with libraries and the web bundle
- TelePOS OS: appliance build with a kiosk
- The `telepos-sysd` daemon, network and display management
- Appliance settings from the till
- Updates through an apt repository
- System management and a system terminal
- Application event journal
- Application version statuses
- Update properties
- Database backup and restore

## 23. Interface

- One interface for the till and the browser
- Light and dark themes, with a switch
- Telegram Desktop styling, including the Night palette
- Adaptive by window width
- Adaptive by input method: finger or cursor
- Collapsible navigation column, collapsed by default
- Own icon set as a font — 33 glyphs, with Material as the remainder
- Field hints and explanations
- Localization: English, Russian, Kazakh, Kyrgyz, Uzbek
- Customer display as a separate window

---

## Not in the code — named, not implied

- **Self-checkout.** The `selfService` workstation role is declared; there are
  no self-service screens and no self-service scenario
- **Till robotics.** Nothing is implemented
- **Loyalty cards.** There are no cards; loyalty is keyed on a phone number
- **Gift certificates.** None (the word "certificate" in the code refers only to
  batch quality)
- **Promo codes and coupons.** None
- **Discount rules** by receipt total, by time of day, by customer. None; a
  discount is entered as a line price and nothing is automatic
- **SMS loyalty confirmation.** The contract exists; the implementation always
  refuses
- **Checks for the scanner, customer display and payment terminal.** The button
  answers "not implemented"
- **Scanner over a serial port, and camera scanning.** The setting is saved;
  nothing acts on it
- **Synchronization between tills.** Push breaks on resending a document; see
  the project status section of the [README](../README.md)
- **Selling from the browser terminal.** Login, enrolment, settings and the
  wire are done and verified live; **the sale itself is not**. It was measured
  rather than estimated: a sale is roughly 60 database calls on a high-frequency
  path, not a rare event, and it needs its own design before implementation
- **Countries other than Kazakhstan.** Rates, tax-id formats and masks for
  Russia, Kyrgyzstan and Uzbekistan exist in the code but have never been
  validated against the actual regulations
