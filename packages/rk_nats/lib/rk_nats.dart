/// NATS and JetStream for Dart, over a native client.
///
/// Core NATS plus JetStream — durable streams and durable consumers — reachable
/// from desktop, appliance and server processes through one binding.
///
/// # What "acknowledged" means here
///
/// JetStream acknowledges a write to the client and fsyncs it later. On a
/// default server, later means up to two minutes. Jepsen's audit of NATS
/// 2.12.1 lost about 14 % of acknowledged messages to a coordinated power cut
/// because of exactly that, and nats-server 2.14.4 — measured on 2026-07-31,
/// the current release — still ships the two-minute default.
///
/// So durability is part of this package's contract rather than an operator's
/// afterthought. [RkNatsDurability.fsyncOnAck] is the default policy; under it
/// a publish is refused unless the library has proved that the server fsyncs
/// before acking. The weaker settings exist and each has a name a reviewer can
/// see in the caller's own source. Every acknowledgement, always, reports what
/// it meant.
///
/// # Choosing this package or `rk_zenoh`
///
/// They are not competitors, and the choice is not close once it is stated
/// plainly.
///
/// Reach for **`rk_nats`** when a message must survive: a sale leaving a till
/// for the shop server, a stock movement, anything replayable and anything that
/// must not be delivered twice. JetStream keeps the messages, remembers where
/// each consumer got to, and a leaf node keeps accepting writes while the
/// shop's uplink is down.
///
/// Reach for **`rk_zenoh`** for the tunnel and for live state: reaching a till
/// behind someone else's router, health and presence, a screen that follows a
/// value. A pub/sub fabric is the right shape for "what is true now" and the
/// wrong shape for "what happened, in order, exactly once".
///
/// Wanting both is normal. Using one for the other's job is the mistake.
library;

export 'src/client.dart';
export 'src/codes.dart';
export 'src/durability.dart';
export 'src/native_library.dart'
    show
        RkNatsLibraryUnavailable,
        RkNatsSymbols,
        rkNatsDefaultLibraryFileName,
        rkNatsExpectedAbiVersion;
export 'src/options.dart';
