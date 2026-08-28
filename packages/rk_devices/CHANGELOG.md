## 0.2.2

- macOS and iOS actually build now. The pod script phase shipped with CRLF line endings and exited 0 without invoking cargo, and the Dart loader had no iOS branch at all -- it asked iOS for a Linux .so. Both fixed and verified on a Mac.

## 0.2.1

Scale readings that were wrong on real frames. Each of these changes what a
caller is handed for bytes it was already receiving.

- **A sign padded away from its digits keeps its sign on a whole line too.**
  Scales right-justify the number inside a fixed-width slot and park the sign
  at its left edge, so a returned half kilo arrives as `-  0.500 kg`. The
  delimited dialects already read that correctly; the `generic` dialect
  required the sign to touch the digits and reported **plus** half a kilo — a
  return booked as a sale.
- **The `generic` dialect reports the unit the wire stated** instead of always
  saying kilograms. `500.0 g` was handed over as `500.0 kg`: this package
  converts nothing on purpose, so a wrong unit is a thousandfold error in a
  quantity that is about to be multiplied by a price. The unit is taken from
  beside the number, not from the end of the line.
- **Over capacity is reported even when the value slot carries no number.**
  `OL,GS,` came back as garbage, losing the one fact the frame carried, and a
  caller then waited out its whole budget for a reading that was never coming.
  The `generic` dialect gained an overload state it did not have at all: a
  word-bounded `OL` marker, so `TOL 1.500 kg` remains a tolerance line and not
  an overload. An over- or under-capacity frame reports a weight of zero — the
  digits in that slot are the full-scale value or blanks, not a measurement.
- **A CAS weight field keeps a comma decimal.** This dialect delimits with the
  character much of Europe writes decimals with, so `ST,GS,+  1,234kg` used to
  split into four fields and leave `+  1` in the weight slot — one kilogram
  reported for 1.234 kg. Only the first two commas delimit now; the rest of
  the line is the weight slot.
- Massa-K still has **no** overload state, deliberately: its marker is not
  established, and a guessed one would stop a sale with a false refusal. Such
  a frame parses and never settles, which the settling rule already reports as
  "answered, never settled".

## 0.2.0

- The package is now a **Flutter FFI plugin**: `flutter build` runs cargo itself
  and puts the library into the application on Windows, Linux and Android.
  Before this there was no `flutter.plugin.platforms` block in the pubspec, and
  the native part reached **no build at all**. macOS and iOS are written but
  have never been built.

## 0.1.0

First release with content. `hasNativeDevices` can now be `true`.

- **Scales.** Weight and tare requests, line framing, and parsing for three
  dialects (`generic`, CAS, Massa-K). A reading carries an exact integer and a
  decimal exponent — never a float — plus the unit the scale named, gross or
  net, and stability as one of stable / unstable / overload / underload.
  Incomplete, garbage and reading are three separate frame outcomes, so a
  caller can resynchronise instead of stalling.
- **A settling rule** that tells "the scale answered and never settled" apart
  from "the scale never said anything". It holds no clock: the caller supplies
  the elapsed time, and the budget is a `Duration`, not a number of attempts.
- **Customer displays.** Reset, clear, home, on/off, blink, brightness, cursor
  and line writing for `led8`, `vfd20` and `lcd2x20`. Text is CP866, and
  characters the page cannot hold — every Kazakh and Kyrgyz letter, and `₸` —
  are counted rather than silently replaced.
- **Cash drawers.** The `ESC p m t1 t2` kick pulse on either pin, with times
  in milliseconds rounded up to the protocol's two-millisecond units, and a
  pulse the protocol cannot carry refused rather than truncated. Whether the
  drawer can report back is asked and answered honestly: it cannot.
- **MDB.** Nine-bit words with the mode bit, the block checksum, ACK/NAK/RET,
  and a command table for the coin changer, the bill validator and both
  cashless addresses — plus `mdbEncodeRaw`, which bypasses the table. The
  five-millisecond response window is published as a number to configure a
  bridge with; nothing here enforces it, because nothing here waits.
- **Partial writes.** A remainder is a continuation on a serial port and
  unknowable on a socket or a raw USB node. A partial count claimed for a
  transport that cannot produce one is refused rather than believed.

Failures cross the FFI boundary as names, never as numbers; the library
allocates nothing a caller must free; every entry point catches panics, and
the crate refuses to compile under `panic = "abort"`.

## 0.0.1

- Name claimed. No content yet: the package proves the publishing
  pipeline, it does not solve the problem.
