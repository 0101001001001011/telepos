/// What a session is opened with, as a plain value.
///
/// Pure Dart, no `dart:ffi`: this is the part a caller reasons about, and it
/// can be built, compared and tested without a native library present.
library;

/// How a session takes part in the fabric. Crosses the boundary by name.
enum SessionMode {
  /// Talks to whoever it finds, and forwards for them. The till's mode.
  peer('peer'),

  /// Talks only through a router. The mode for a terminal behind one link.
  client('client'),

  /// Forwards for others. The shop server's mode.
  router('router');

  const SessionMode(this.wireName);

  /// The name as it crosses the boundary.
  final String wireName;
}

/// What to do when a link is full.
enum CongestionControl {
  /// Discard rather than wait. Right for telemetry.
  drop('drop'),

  /// Wait rather than discard. Right for anything a shift depends on.
  block('block');

  const CongestionControl(this.wireName);

  /// The name as it crosses the boundary.
  final String wireName;
}

/// Zenoh's seven priorities.
///
/// Per-message *reliability* is deliberately absent: `zenoh::qos::Reliability`
/// is gated behind the crate's unstable API in 1.9.0, so this package cannot
/// offer it while staying in the stable subset.
enum Priority {
  realTime('real_time'),
  interactiveHigh('interactive_high'),
  interactiveLow('interactive_low'),
  dataHigh('data_high'),
  data('data'),
  dataLow('data_low'),
  background('background');

  const Priority(this.wireName);

  /// The name as it crosses the boundary.
  final String wireName;
}

/// Whether a sample was written or removed.
enum SampleKind {
  put('put'),
  delete('delete');

  const SampleKind(this.wireName);

  /// The name as it crosses the boundary.
  final String wireName;

  /// Parse a name coming back from the native side.
  static SampleKind parse(String name) => switch (name) {
    'put' => SampleKind.put,
    'delete' => SampleKind.delete,
    _ => throw ArgumentError.value(name, 'name', 'not a sample kind'),
  };
}

/// Whether the session keeps the Zenoh ID it had last time.
///
/// This is the decision the package exists to make explicit. A recreated
/// session gets a fresh Zenoh ID unless told otherwise, and anything that
/// recorded the old one as *the address of that till* is now holding a dead
/// one — messages to it are accepted and delivered nowhere.
sealed class ZenohIdentity {
  const ZenohIdentity();

  /// The Zenoh ID is an ephemeral handle. Address peers by their durable
  /// identity in the key expression, and use liveliness to notice comings and
  /// goings.
  ///
  /// Measured: a restarted till is reachable again by durable identity in
  /// well under a second, while everything addressed by the old Zenoh ID is
  /// silently lost until the address is refreshed. See `doc/stale-zid.md`.
  const factory ZenohIdentity.ephemeral() = EphemeralZenohId;

  /// The Zenoh ID is pinned, so routes survive a restart.
  ///
  /// Requires TLS. Whoever claims a pinned ID first keeps it — measured, see
  /// `doc/stale-zid.md` — so an unauthenticated pin lets any machine on the
  /// network lock a till out of its own fabric by booting first.
  const factory ZenohIdentity.pinnedTo(String hex) = PinnedZenohId;

  /// The Zenoh ID is derived from a durable identity, and pinned.
  ///
  /// The same requirement applies, for the same reason: the derivation is a
  /// hash, not a secret, and anyone who knows the terminal's name can compute
  /// it.
  const factory ZenohIdentity.derivedFrom(String identity) = DerivedZenohId;
}

/// See [ZenohIdentity.ephemeral].
final class EphemeralZenohId extends ZenohIdentity {
  const EphemeralZenohId();
}

/// See [ZenohIdentity.pinnedTo].
final class PinnedZenohId extends ZenohIdentity {
  const PinnedZenohId(this.hex);

  /// Lowercase hex, at most sixteen bytes, and **not** starting with `0`:
  /// Zenoh stores the id as a little-endian integer and refuses a leading
  /// zero. The native side validates with Zenoh's own parser, so a bad value
  /// is refused when the configuration is built rather than when the session
  /// opens.
  final String hex;
}

/// See [ZenohIdentity.derivedFrom].
final class DerivedZenohId extends ZenohIdentity {
  const DerivedZenohId(this.identity);

  /// The durable identity, such as `till-17.shop-3.telepos`. This is also what
  /// belongs in the certificate subject that actually authenticates the peer.
  final String identity;
}

/// Everything a session is opened with.
class ZenohConfig {
  ZenohConfig({
    this.mode = SessionMode.peer,
    this.identity = const ZenohIdentity.ephemeral(),
    List<String> connect = const [],
    List<String> listen = const [],
    this.multicastScouting = false,
    this.gossipScouting = true,
    this.extraJson5,
  }) : connect = List.unmodifiable(connect),
       listen = List.unmodifiable(listen);

  /// How this session takes part.
  final SessionMode mode;

  /// Whether the Zenoh ID survives a restart, and how.
  final ZenohIdentity identity;

  /// Endpoints this session dials, such as `tls/shop-3.telepos:7447`.
  final List<String> connect;

  /// Endpoints this session listens on.
  final List<String> listen;

  /// Whether to look for peers by UDP multicast.
  ///
  /// Off by default. Multicast finds peers on one shop LAN and nowhere across
  /// it, and Zenoh does not traverse NAT in any case — reaching a till behind
  /// someone else's router is the relay's job, not the fabric's.
  final bool multicastScouting;

  /// Whether to learn about further peers from the ones already known.
  final bool gossipScouting;

  /// A JSON5 object merged underneath the settings above.
  ///
  /// This is how TLS material reaches the session. Anything set here is
  /// overridden by the typed settings, one key at a time — a duplicated key
  /// would otherwise make Zenoh reject the whole document.
  final String? extraJson5;

  /// Whether this configuration turns on TLS or QUIC anywhere.
  ///
  /// A pinned identity without this is refused by the native side, and the
  /// same check is made here so a caller finds out before spawning an isolate.
  bool get isAuthenticated {
    bool secure(String e) {
      final lower = e.toLowerCase();
      return lower.startsWith('tls/') || lower.startsWith('quic/');
    }

    final extra = extraJson5;
    return connect.any(secure) ||
        listen.any(secure) ||
        (extra != null &&
            (extra.contains('root_ca_certificate') ||
                extra.contains('enable_mtls')));
  }

  /// Why this configuration cannot be opened, or `null` if it can.
  ///
  /// Kept as a value rather than a throw so a settings screen can show it
  /// while the user is still typing.
  String? get refusalReason {
    if (identity is! EphemeralZenohId && !isAuthenticated) {
      return 'A pinned Zenoh ID needs TLS. Whoever claims the ID first keeps '
          'it, so without a certificate to check, any machine on the network '
          'can take this till out of the fabric by starting before it.';
    }
    if (identity is PinnedZenohId) {
      final hex = (identity as PinnedZenohId).hex;
      if (hex.isEmpty) return 'A pinned Zenoh ID cannot be empty.';
      if (hex.startsWith('0')) {
        return 'A Zenoh ID cannot start with a zero: $hex.';
      }
      if (hex.length > 32) {
        return 'A Zenoh ID is at most sixteen bytes, or thirty-two hex '
            'digits: $hex.';
      }
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
        return 'A Zenoh ID is hexadecimal: $hex.';
      }
    }
    if (identity is DerivedZenohId &&
        (identity as DerivedZenohId).identity.isEmpty) {
      return 'A derived Zenoh ID needs a non-empty identity.';
    }
    return null;
  }
}
