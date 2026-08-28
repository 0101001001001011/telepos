# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

A reply within a week. If the vulnerability is confirmed, the fix ships as a
version of its own, and the description is published after that version is
out, not before.

## What counts as a vulnerability here

The native library performs no I/O. It opens nothing, sleeps never, spawns no
thread, and every call is a pure function of its arguments. There is no socket
to hijack, no connection to downgrade and no state to poison between calls.

What is left is a **parser fed by whatever is on the other end of the wire**,
and a scale, a display or an MDB peripheral is a device anyone with access to
the counter can swap. Every byte handed to this package is treated as hostile
input, so these count:

- **Reading or writing outside a buffer** in the native part — on a truncated
  frame, on a length field that disagrees with the frame, on a nine-bit MDB
  block whose checksum the attacker chose. Memory corruption, double free and
  unbounded allocation are in scope.
- **A frame that parses into a reading it does not carry.** A weight gets
  multiplied by a price, so a byte sequence that yields a *stable* reading when
  the scale reported motion, or an exponent off by one, is a money defect and
  is handled as one.
- **A claim the transport never made.** A partial write count is refused for a
  socket and for a raw USB node because neither can supply one; any path that
  fabricates a count is a vulnerability rather than a convenience.
- **Loading the library from a path an outsider can control.** The binding
  searches an explicit path, then `RK_DEVICES_LIBRARY`, then the system loader.
  All three are trusted input, and an application that takes any of them from
  an untrusted source has handed an outsider code execution inside its own
  process.

## What this package does not do

**It opens no device.** Bytes are handed in and handed back. The serial port,
the socket and the raw USB node belong to the caller, along with the
permissions on them.

**It holds no deadline and owns no bus.** MDB's five-millisecond reply window
and a stepper's pulse train belong to a peripheral controller. Nothing here
enforces timing, so nothing here can be attacked by breaking it — and no device
failure can block taking money, because there is no wait here to make unbounded.

**It authenticates nobody.** None of these protocols has a notion of identity:
a scale on a serial line is trusted because of where the cable goes. If that
assumption does not hold in your installation, it has to be answered at the
wire, not here.
