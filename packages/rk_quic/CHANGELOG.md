## 0.2.2

- **Every call on `QuicServer` now gets its own reply, however many are in
  flight.** Before, a call took whichever reply arrived next, so two
  overlapping calls both received the first reply and the second went to
  nobody. With every call succeeding this was invisible; when one failed, its
  status was also handed to a healthy call beside it. A server writing to a
  stream the browser had just abandoned (`peerGone`) could see a concurrent
  write into a live subscription report `peerGone` too — and close a
  subscription that was working.
- Replies are now matched to calls by id. A call still waiting when the
  endpoint is stopped completes with `notRunning` instead of never completing.
- `test/concurrent_commands_test.dart` holds it: a write to an unknown session
  and a `stop()` in flight together must answer `unknownHandle` and `ok`
  respectively. Measured failing before the change (`stop()` answered
  `unknownHandle`), passing after.
- No ABI change and no change to the Rust library: the fix is entirely in the
  Dart isolate plumbing.

## 0.2.1

- **An endpoint bound to an IPv6 address now asks for dual stack explicitly**,
  instead of leaving `IPV6_V6ONLY` at whatever the operating system defaults to.
  `[::]:4433` used to mean every address on Linux and only the IPv6 half of them
  on Windows, with nothing on either side saying which — and the missing half is
  the one a browser reaches first, because Windows resolves a machine name and
  `localhost` to IPv6 ahead of IPv4.
- The failure this fixes was silent in both directions. A client on the family
  the socket did not carry sent packets and heard nothing: Chrome reports
  `QUIC_NETWORK_IDLE_TIMEOUT` with `num_undecryptable_packets: 0`, and a
  `wtransport` client simply times out after thirty seconds. `curl` is no help
  at all — it answers 200 through an address the browser cannot use, because it
  picks a family differently.
- `tests/dual_stack.rs` holds it there: one listener on `[::]:0`, a real
  WebTransport client over `[::1]` and over `127.0.0.1`, both required to open a
  session. Measured failing before the change on Windows 11 (the IPv4 half timed
  out), passing after.
- No ABI change: generation 2, and `QuicServerConfig` is untouched. A caller
  that was passing `0.0.0.0` gets exactly what it did before.

## 0.2.0

- Bidirectional streams: an exchange can now be a question and its answer, a
  subscription, or a run reporting progress. C ABI generation 2.
- `server.events` gains `streamOpened`, `streamData` and `streamClosed`, each
  carrying a `streamId` alongside the session. A session is not an exchange: a
  browser may have several questions in flight at once, and only the stream
  says which answer belongs to which.
- `QuicServer.sendOn(sessionId, streamId, message)` writes back into the stream
  a peer opened **without ending it**; `QuicServer.closeStream()` ends it. Which
  kind of exchange it is belongs to the caller, not to the transport.
- **`StreamClosed` is not an unsubscribe.** The endpoint reads a message whole
  before reporting it, so it learns of a request only once the client has
  finished writing — and the event therefore arrives immediately behind
  `StreamData`, identically for a one-off question and for a subscription meant
  to last an hour. Treating it as "the client went away" cancels every
  subscription the moment it is created. A peer that really has gone is learned
  from a write refused with `peerGone`, and from `sessionClosed`.
- `sessionClosed` now leaves the queue only after the session has been
  forgotten. The previous order was racy: under concurrent sessions a send
  could succeed after its own close event had already been read.
- An event field of the wrong type no longer throws. The reader used a cast,
  which threw instead of yielding null, on the isolate where nothing would have
  reported it — so one oddly-typed field from a newer library looked like
  "events stopped arriving" rather than like one odd event.
- C ABI generation is **2**: `rk_quic_stream_send` and `rk_quic_stream_close`
  were added. A Dart side written against generation 2 refuses a generation-1
  library by name rather than dying on a missing symbol.

## 0.1.0

The first version with a native part — and a QUIC endpoint that speaks first.

- `QuicServer.start()` brings up an HTTP/3 endpoint and accepts WebTransport
  sessions; `server.events` yields `sessionOpened`, `sessionClosed`, `datagram`
  and `streamMessage`; `server.send()` writes into a session over a stream
  (ordered, retransmitted) or as a datagram. Implemented on **quinn** — see the
  README for why not quiche.
- Everything that blocks — waiting for an event and sending reliably — is on
  helper isolates: the interface isolate never enters the native part.
- `idleTimeoutMs` is mandatory and has no "never" value. Measured: without it a
  client that vanished without warning is not noticed at all — the server had
  still not seen `sessionClosed` twenty seconds after the client left.
- The package does not issue certificates: that is `rk_pki`'s job. The chain has
  one representation across both packages —
  `rustls_pki_types::CertificateDer`.

**Breaking.** `rkQuicVersion` was a `const String` and is now a `String?`, read
out of the loaded library. A constant would go on reporting the right version
while a year-old library sat next to it; that is what the version was raised
for.

- `hasNativeTransport` is now a real probe: it opens the library and checks the
  ABI generation. No longer a stub returning `false`.
- `probeNativeLibrary()` returns a `NativeProbe`: `loaded`,
  `unsupportedPlatform`, `libraryMissing`, `symbolMissing`, `abiMismatch`. Not
  one of these cases throws an exception or brings the process down.
- Statuses cross the boundary **by name**, not by number; an unfamiliar name
  becomes `RkQuicStatus.unrecognised` rather than somebody else's branch.
- The native part builds and reaches the application on Windows, Linux and
  Android. For macOS and iOS the build files are written but **not confirmed by
  a build** — there is no Mac available.
- The package is safe to import in a browser: `dart:ffi` is behind a
  conditional import.

## 0.0.1

- Name claimed. No content yet: the package proves the publishing
  pipeline, it does not solve the problem.
