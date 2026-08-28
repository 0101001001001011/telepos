# Changelog

## 0.1.0

- First release. An mDNS responder and a DNS-SD browser, both halves, over a
  native library — no system daemon needed on any platform.
- Responder: service announcement (`PTR`, `SRV`, `TXT`, `A`, `AAAA` and the
  DNS-SD service-enumeration pointer), name-conflict resolution with probing
  and tie-breaking (RFC 6762 §8.1, §8.2), repeated announcement (§8.3),
  goodbye at zero TTL (§10.1), and separate answers for the instance and the
  host.
- Browser: `<name>.local` resolution, browsing a service type with arrivals and
  departures, `TXT` split into key/value pairs, and a cache with real lifetimes
  and known-answer suppression (§7.1).
- IPv4 and IPv6, unicast replies to the `QU` bit (§5.4), every failure returned
  as a value, and no panic across the FFI boundary.
- **Sends on every interface**, never on the one the routing table prefers.
  Measured 2026-08-05: without `IP_MULTICAST_IF` the datagram left by a virtual
  switch adapter on a four-interface machine, silently. There is no
  default-send path in this package, and `rust/tests/every_interface.rs` is
  what keeps it that way.
- Shares UDP 5353 with whatever already holds it — Chrome on Windows,
  `avahi-daemon` on Linux, `mDNSResponder` on Apple — and reports `portInUse`
  honestly when sharing is refused.
