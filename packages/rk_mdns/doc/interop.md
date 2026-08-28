# Interoperability: the proof that is not our own code

A responder and a browser written from the same source agree with each other
whether or not either agrees with the RFC. So the suites in this package are
not the evidence that matters. **This is**: a third-party implementation,
`avahi-daemon 0.8`, seeing what `rk_mdns` announced, and `rk_mdns` seeing what
Avahi announced.

Everything below is verbatim. Run 2026-08-06 on Ubuntu 26.04, kernel 7.0,
`avahi-daemon 0.8`, `rustc 1.97.1`.

## Why it runs on one host

Multicast does not cross between the development machine and the test machine
— measured with `tcpdump`: the query leaves, zero packets come back, and a
private group gives zero in both directions. That is a property of the network
between them.

It does not weaken the proof. What is being checked is whether **another
implementation** can read what this one writes, and Avahi on the same host is
as foreign to this code as Avahi on another. `loopbackInterface: true` is what
puts the two on a link they share.

## The daemon is there, and it holds the port

```
== avahi-daemon --version
avahi-daemon 0.8
== ss -lunp | grep 5353
UNCONN 0      0                                0.0.0.0:5353      0.0.0.0:*
UNCONN 0      0                                   [::]:5353         [::]:*
```

`rk_mdns` binds the same port beside it. That is the ordinary condition, and
`SO_REUSEADDR`/`SO_REUSEPORT` is what makes it possible.

## 1. Avahi browses a service rk_mdns announced

```
== announce for 25s
-- rk_mdns says:
Claimed { instance: "till-3._rkproof._tcp.local", host: "till-3.local", addresses: ["192.168.1.205"], interfaces: 1 }
Announced { carried: 1, interfaces: 1 }

== avahi-browse -r -t _rkproof._tcp
+ docker0 IPv4 till-3                                        _rkproof._tcp        local
+  ens18 IPv4 till-3                                        _rkproof._tcp        local
+     lo IPv4 till-3                                        _rkproof._tcp        local
=  ens18 IPv4 till-3                                        _rkproof._tcp        local
   hostname = [till-3.local]
   address = [192.168.1.205]
   port = [8443]
   txt = ["scheme=https" "path=/rk" "quic=4433"]
```

The `SRV`, the `TXT` and the `A` all arrived intact, and Avahi resolved them
without complaint. (Avahi lists the `PTR` once per interface it knows of and
then fails to resolve on the two this run deliberately did not announce on —
which is the interface filter working, not a fault.)

## 2. Avahi resolves the host name

```
== avahi-resolve -n till-3.local
till-3.local	192.168.1.205
```

## 3. Avahi enumerates the service type

`_services._dns-sd._udp.local`, RFC 6763 §9 — what `avahi-browse -a` asks for
and what a responder that ignores it is invisible to:

```
== avahi-browse -a -t | grep rkproof
+ docker0 IPv4 till-3                                        _rkproof._tcp        local
+  ens18 IPv4 till-3                                        _rkproof._tcp        local
+     lo IPv4 till-3                                        _rkproof._tcp        local
```

## 4. The goodbye is honoured (RFC 6762 §10.1)

The record's lifetime is two minutes. If the goodbye were not sent or not
understood, Avahi would go on listing the service for that long.

```
-- while it is running, avahi-browse counts:
3
-- waiting for the clean stop...
stopping; the goodbye goes out before this returns
stopped
-- after the goodbye, avahi-browse counts:
0
-- and avahi-resolve:
Failed to resolve host name 'till-bye.local': Timeout reached
```

Three seconds after the stop, not two minutes.

**This check found a real mistake in how it was being run.** The first attempt
stopped the responder with `SIGTERM`; the process died without unwinding,
`stop()` never ran, no goodbye was sent, and Avahi went on listing a service
that was gone — which looked exactly like a defect in the responder and was a
defect in the harness. `examples/announce.rs` now takes a duration and stops
the way an application does.

## 5. rk_mdns browses a service Avahi announced

The other direction. `avahi-publish -s avahi-side _rkreverse._tcp 9443
quic=1234 path=/from-avahi`, then this package's browser:

```
ServiceFound { instance: "avahi-side._rkreverse._tcp.local" }
ServiceResolved { instance: "avahi-side._rkreverse._tcp.local", host: "rk.local", port: 9443,
                  addresses: ["127.0.0.1", "::1"],
                  txt: [TxtPair { key: "quic", value: "1234" },
                        TxtPair { key: "path", value: "/from-avahi" }] }
ServiceResolved { …, addresses: ["127.0.0.1", "192.168.1.205", "::1", "fe80::be24:11ff:fec8:cd7b"], … }
ServiceResolved { …, addresses: ["127.0.0.1", "172.17.0.1", "192.168.1.205", "::1", "fe80::…"], … }
```

Three `ServiceResolved` because Avahi announces per interface and the address
set grows as they arrive — a resolution is re-reported when what a caller would
act on changes, and suppressed when it does not.

## 6. A name conflict against a third party

Avahi claims the name first; `rk_mdns` probes, finds it taken, and moves. This
is the strongest form of the check, because the conflicting party is not our
code:

```
== avahi-publish -s rk-contested _rkconflict._tcp 7443     (Avahi, first)
== then rk_mdns tries the same name:
NameConflict { from: "rk-contested._rkconflict._tcp.local",
               to:   "rk-contested-2._rkconflict._tcp.local",
               detail: "another host answered for rk-contested._rkconflict._tcp.local with a SRV record of its own" }
Claimed { instance: "rk-contested-2._rkconflict._tcp.local", host: "rk-contested-2.local", … }

== what avahi-browse -r sees afterwards:
=  ens18 IPv4 rk-contested-2       _rkconflict._tcp     local
   hostname = [rk-contested-2.local]   port = [8443]
=  ens18 IPv4 rk-contested         _rkconflict._tcp     local
   hostname = [rk.local]               port = [7443]
```

Two services, two names, both resolvable, and the host names moved together —
which is the point: renaming only the service instance would have left two
hosts answering `rk-contested.local`.

## 7. The measurement that decided the interface filter

This one is not about the protocol. It is about which addresses go into the
announcement, and a third-party resolver is the only honest judge of it.

The host has three IPv4 interfaces:

```
lo      127.0.0.1/8
ens18   192.168.1.205/16
docker0 172.17.0.1/16
```

Announcing on **all** of them, and asking Avahi to resolve the result:

```
Claimed { instance: "till-all._rkall._tcp.local", host: "till-all.local",
          addresses: ["192.168.1.205", "172.17.0.1"], interfaces: 4 }
-- what avahi-resolve picks:
till-all.local	172.17.0.1
```

**Avahi chose the docker bridge.** A client following that answer connects to
an address nothing is listening on and waits for a timeout. Nothing here is
broken — every record is correct — and the service is still unusable.

Confined to one named interface:

```
Claimed { instance: "till-one._rkone._tcp.local", host: "till-one.local",
          addresses: ["192.168.1.205"], interfaces: 1 }
-- what avahi-resolve picks now:
till-one.local	192.168.1.205
```

That is why `ServiceAnnouncement.interfaces` exists, why the package will not
guess which interface is real, and why the rule here is stricter than the one
for a certificate: in a certificate a spare `iPAddress` is *checked* and costs
nothing, in an announcement it is *tried* and costs a client a timeout.

Filtering by address would not have worked either: a rule dropping `172.16/12`
drops the shop networks this package is for.

## What this leaves unproven

- **Apple.** `dns-sd -B` and `dns-sd -L` have not been run against this
  responder. Until they are, macOS and iOS support is a build, not a proof.
- **Two machines.** Everything above is one host. The protocol is the same on a
  segment, but the interface fan-out cannot be observed from inside one
  machine.
- **A large network.** Known-answer suppression and the doubling query interval
  are checked by unit tests over the cache, not by watching a segment with
  fifty devices on it.

## Reproducing it

```bash
sudo apt-get install -y avahi-utils avahi-daemon
cd rust
cargo build --release --examples

# 1-4
RK_MDNS_INTERFACES=eth0 ./target/release/examples/announce till-3 _rkproof._tcp.local 8443 5353 25 &
avahi-browse -r -t _rkproof._tcp
avahi-resolve -n till-3.local
avahi-browse -a -t | grep rkproof
wait                       # the goodbye goes out here
avahi-resolve -n till-3.local     # must now time out

# 5
avahi-publish -s avahi-side _rkreverse._tcp 9443 quic=1234 &
./target/release/examples/browse _rkreverse._tcp.local

# 6
avahi-publish -s rk-contested _rkconflict._tcp 7443 &
./target/release/examples/announce rk-contested _rkconflict._tcp.local 8443 5353 25
```
