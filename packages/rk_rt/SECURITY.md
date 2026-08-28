# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

A reply within a week. If the vulnerability is confirmed, the fix ships as a
version of its own, and the description is published after that version is
out, not before.

## What counts as a vulnerability here

Version 0.0.1 is seventeen lines of Dart. There is no native part, no socket,
no file, no thread and no computation: the single entry point is a probe that
returns `false`. There is no attack surface to describe, and copying one from a
package that has an attack surface would be worse than saying nothing.

What is worth a private report is the supply chain around that emptiness:

- **A published version that does something this file says it does not** — a
  release that has gained a native part, a socket or a file read without the
  `CHANGELOG.md` entry that says so.
- **A release not built from the source in this repository.**

## What this package does not do

Everything, and it says so at run time rather than returning a plausible zero.
There is no control loop, no command set and no telemetry.

The absence is a decision rather than an unfinished job: a control loop cannot
run in a garbage-collected runtime, and with servo drives the loop is closed
inside the drive, so this package may never need more than a protocol. If it
ever grows past one, this file grows a real threat model in the same commit.
