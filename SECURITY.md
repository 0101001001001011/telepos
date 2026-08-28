# Security Policy

TelePOS handles money, fiscal receipts and customer data. Security reports are
taken seriously and are welcome from anyone.

## Reporting a vulnerability

**Do not open a public issue for security problems.**

Email **4playdev@gmail.com** with:

- a description of the issue and why you believe it is a security problem;
- the affected version or commit;
- steps to reproduce, ideally a minimal case;
- the impact you were able to demonstrate.

You will get an acknowledgement within 5 working days. Once the issue is
confirmed, you will be told the intended fix and the release it is targeted
for. Please give us a reasonable window to ship a fix before disclosing
publicly.

If you would like credit in the release notes, say so in your report.

## Supported versions

Fixes land on the `main` branch and ship in the next release. Older releases
are not patched — upgrade to the latest version.

## Scope

In scope:

- the Flutter application in this repository;
- **the QUIC/WebTransport wire between till and browser terminal** — operation
  authorization, session issue and revocation, the attempt lock, terminal
  enrolment by one-time code, and anything that could let a terminal reach an
  operation it has no permission for;
- **the installation's own certificate authority** (`packages/rk_pki`):
  certificate issue, the one-time release of the root, and trust installation;
- the local SQLite database and its encryption;
- CouchDB replication (authentication, transport, conflict handling);
- the Telegram transport (session storage, message encryption, bot command
  handling);
- fiscal and payment integrations as implemented in this repository;
- receipt and cash-drawer handling.

Out of scope:

- vulnerabilities in third-party services TelePOS talks to (WebKassa, OFD
  providers, payment terminals) — report those to their vendors;
- issues that require an already-compromised operating system or physical
  access to an unlocked terminal;
- outdated dependencies with no demonstrated exploit path in TelePOS.

## Deployment notes

Two things are the operator's responsibility, not the application's:

- **Telegram API credentials.** TelePOS does not ship an `api_id`/`api_hash`.
  Register your own application at [my.telegram.org](https://my.telegram.org)
  and pass the credentials at build time via `--dart-define`, or enter them in
  the Telegram setup screen. Never commit them.
- **CouchDB exposure.** Do not publish a CouchDB instance to the internet
  without TLS and per-organization credentials.
