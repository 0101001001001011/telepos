# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

A reply within a week. If the vulnerability is confirmed, the fix ships as a
version of its own, and the description is published after that version is
out, not before.

## What counts as a vulnerability here

The package loads native code and runs models over camera frames. It opens no
socket of its own: nothing here fetches a model and nothing here reaches a
network. The surface is what it is handed and what it is asked to load.

- **A model accepted that the manifest did not describe.** The delivery chain
  checks a schema, an ABI generation, a length, a SHA-256 and a version pin.
  Any route that reaches a load past one of those checks is a vulnerability —
  to the runtime a model file is code.
- **A raw frame leaving the worker that owns it.** The contract has no method
  that could return anything byte-shaped, and the structural test that enforces
  it derives its roots from the `export` directives so a new one cannot be
  added quietly. A declaration that hands a frame back is a personal-data leak
  and is reported as one.
- **Reading or writing outside a buffer** in the native part, memory
  corruption, double free, or a frame freed while a run still borrows it.
- **Loading a library from a path an outsider can control** — the binding
  library and the inference runtime alike. `bindingLibraryPath` and
  `runtimeLibraryPath` are trusted input.

## What this package does not do

**It does not fetch models and it does not decide what to trust.** The
manifest, its digests and the decision to install a version are the caller's.
The package refuses what does not match and installs nothing on its own.

**It does not store frames and it does not link them to a person.** A frame
lives for the run that borrows it. Retention of anything derived from one
belongs to the consuming system, which is where a retention period is declared.

**It does not promise accuracy, and accuracy is not a security report.**
`visitorCount` is an hourly trend, not a count. `unscannedItemHint` is a filter
that narrows what a person reviews, not a detector of theft. Describing either
as more than that is a correctness problem — and a serious one where somebody
is accused on the strength of it — but it does not go through this channel.

**The session path is not built.** Loading a model reaches `NotImplemented`,
and there is deliberately no stub returning an empty result: on a quiet camera
a stub and a working engine look exactly alike.
