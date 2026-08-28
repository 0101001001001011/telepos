/*
 * rk_mdns — the C ABI, and the authoritative statement of it.
 *
 * Hand-written, and the Dart bindings are hand-written against it. `ffigen`
 * was not used: this surface is small enough to read in one screen, ffigen
 * needs LLVM installed on every machine that regenerates it, and a generated
 * file in git invites the question of which copy is true. Instead
 * `test/abi_surface_test.dart` parses this header and fails if the Dart
 * bindings and this file disagree about the exported names — the drift ffigen
 * would have prevented is caught, without the toolchain.
 *
 * THREE RULES HOLD EVERYWHERE BELOW.
 *
 * Failure is a returned value (И144). No function here unwinds into the
 * caller and none aborts: a panic in Rust comes back as the status "panic".
 *
 * Enumerations cross by name (И147). A status is a NUL-terminated name such as
 * "ok" or "portInUse", never an integer. It points into static storage: the
 * caller must not free it, and it is valid for the life of the process.
 *
 * Freeing is one-sided and deterministic (И146). Whoever allocated frees.
 * Every pointer this library returns is either static (never freed) or was
 * allocated by Rust and must come back through rk_mdns_string_free. The caller
 * never calls free() on it, and Rust never frees a pointer the caller owns.
 */

#ifndef RK_MDNS_H
#define RK_MDNS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Generation of this ABI. Bumped when a signature or an ownership rule
 * changes — not when the package version changes. A caller that does not know
 * the generation it finds must refuse the library rather than guess. */
#define RK_MDNS_ABI_VERSION 1

/* Returns the generation the loaded library implements. Cannot fail. */
uint32_t rk_mdns_abi_version(void);

/* Returns the library version, NUL-terminated, in static storage.
 * Ownership: not the caller's. Do not free. */
const char *rk_mdns_version(void);

/* Frees a string this library allocated.
 * Ownership: takes the pointer back. Null is accepted and does nothing.
 * Passing a static pointer, a foreign pointer, or one already freed is
 * undefined behaviour. */
void rk_mdns_string_free(char *s);

/* Returns the detail behind the last failure on the calling thread, or NULL
 * when there is none. Reading clears it, so a message is never reported twice.
 * Ownership: the caller's. Free with rk_mdns_string_free. */
char *rk_mdns_last_error(void);

/* --- the responder ------------------------------------------------------ */

/* Starts a responder: probes for the name, claims it, announces the service,
 * and answers questions about it until stopped.
 *
 * config_json is UTF-8 JSON:
 *   {
 *     "instanceName":       "till-3",                 // one label
 *     "serviceType":        "_telepos._tcp.local",
 *     "hostName":           "till-3.local",           // optional
 *     "port":               8443,
 *     "txt":                ["quic=4433", "path=/rk"],// optional
 *     "addresses":          ["10.0.0.7"],             // optional; empty = every interface
 *     "hostTtlSeconds":     120,                      // optional
 *     "serviceTtlSeconds":  4500,                     // optional
 *     "mdnsPort":           5353,                     // optional; tests use a private port
 *     "probe":              true,                     // optional
 *     "ipv6":               true,                     // optional
 *     "loopbackInterface":  false,                    // optional
 *     "multicastLoopback":  true                      // optional
 *   }
 * An unknown key is an error, not something ignored: a typo must not look
 * like a setting that took effect.
 *
 * On "ok" the handle is written through out_handle. On anything else
 * out_handle is untouched and rk_mdns_last_error carries the detail.
 *
 * "portInUse" is an ordinary outcome rather than a fault: Chrome holds UDP
 * 5353 on Windows whenever it is running, avahi-daemon holds it on Linux, and
 * mDNSResponder holds it on every Mac. The bind asks to share it; this status
 * means sharing was refused.
 *
 * "noInterface" means there is nothing to announce on. There is deliberately
 * no fallback to sending by whatever the routing table prefers — measured
 * 2026-08-05 to be a virtual switch adapter on a four-interface machine, so
 * the announcement left by a door no device is behind, silently.
 *
 * Ownership: nothing is transferred. The handle is a NAME, not a pointer —
 * a stale one is "unknownHandle", never a use-after-free. */
const char *rk_mdns_responder_start(const char *config_json, uint64_t *out_handle);

/* Stops a responder. Returns only after the goodbye — the records with a
 * lifetime of zero, RFC 6762 §10.1 — has gone out, because that is what stops
 * a tablet holding a dead till in its cache for the next two minutes.
 *
 * Stopping something already stopped is "notRunning", not a failure: during
 * shutdown a double stop is ordinary, and making it an error only teaches
 * callers to ignore the result. */
const char *rk_mdns_responder_stop(uint64_t handle);

/* Writes what the responder ended up with, as JSON:
 *   {
 *     "instance":   "till-3._telepos._tcp.local",
 *     "host":       "till-3.local",
 *     "addresses":  ["10.0.0.7"],
 *     "claimed":    true,
 *     "interfaces": [{"name":"eth0","address":"10.0.0.7","index":2,
 *                     "sent":6,"failed":0}]
 *   }
 *
 * This is where the name AFTER a conflict is read. A caller that asked for
 * "till-3" and finds "till-3-2" has two tills configured alike, and that has
 * to be visible rather than inferred from a tablet reaching the wrong one.
 *
 * "interfaces" is the evidence behind "sent on every interface": an entry with
 * sent == 0 while the responder has announced means the datagram is going out
 * one door.
 *
 * Ownership: on "ok" the caller owns *out_json and frees it with
 * rk_mdns_string_free. */
const char *rk_mdns_responder_state(uint64_t handle, char **out_json);

/* Waits up to timeout_ms for the responder's next event and writes it as JSON.
 *
 * "ok"         — an event was written; the caller now owns *out_json.
 * "wouldBlock" — the wait expired with nothing to report; *out_json is
 *                untouched.
 *
 * The two are distinct so a loop can tell "nothing happened" from "something
 * happened and was handled". timeout_ms is capped at 60000 so a caller cannot
 * park a thread for an hour.
 *
 * Event JSON carries a "kind" NAME — "probing", "nameConflict", "claimed",
 * "announced", "answered", "goodbye", "error" — never a number.
 *
 * Ownership: on "ok" the caller owns *out_json. */
const char *rk_mdns_responder_poll(uint64_t handle, uint32_t timeout_ms,
                                   char **out_json);

/* --- the browser -------------------------------------------------------- */

/* Starts browsing a DNS-SD service type.
 *
 * config_json is UTF-8 JSON:
 *   {
 *     "serviceType":       "_telepos._tcp.local",
 *     "mdnsPort":          5353,   // optional
 *     "ipv6":              true,   // optional
 *     "loopbackInterface": false,  // optional
 *     "multicastLoopback": true    // optional
 *   } */
const char *rk_mdns_browser_start(const char *config_json, uint64_t *out_handle);

/* Stops a browser. "notRunning" for one already stopped. */
const char *rk_mdns_browser_stop(uint64_t handle);

/* Waits up to timeout_ms for the browser's next event and writes it as JSON.
 *
 * Kinds: "serviceFound", "serviceResolved", "serviceLost", "queried",
 * "error". "serviceResolved" carries host, port, addresses and the TXT record
 * already split into key/value pairs, and it is only sent once there is enough
 * to connect with — a service reported earlier would put an entry in an
 * operator's list that fails at the first tap.
 *
 * Ownership: on "ok" the caller owns *out_json. */
const char *rk_mdns_browser_poll(uint64_t handle, uint32_t timeout_ms,
                                 char **out_json);

/* Resolves one <name>.local and writes {"host":…,"addresses":[…]} as JSON.
 *
 * Blocking, bounded by "timeoutMs" in the configuration:
 *   {
 *     "hostName":          "till-3.local",
 *     "timeoutMs":         3000,  // optional
 *     "mdnsPort":          5353,  // optional
 *     "ipv6":              true,  // optional
 *     "loopbackInterface": false, // optional
 *     "multicastLoopback": true   // optional
 *   }
 *
 * "ok" with an empty address list means the question was asked and nothing
 * answered. That is an answer, not a failure: on a network that filters
 * multicast it is the EXPECTED one, and making it an error would leave a
 * filtered network indistinguishable from a broken call.
 *
 * Ownership: on "ok" the caller owns *out_json. */
const char *rk_mdns_resolve_host(const char *config_json, char **out_json);

/* --- diagnosis ---------------------------------------------------------- */

/* Writes the interfaces this host would announce on, as JSON:
 *   [{"name":"eth0","address":"10.0.0.7","index":2}]
 *
 * Exists because "the till is invisible" has two causes that look identical
 * from a tablet — a network that filters multicast, and a host announcing out
 * of the wrong door — and only this tells them apart. Starts nothing.
 *
 * Ownership: on "ok" the caller owns *out_json. */
const char *rk_mdns_interfaces(uint8_t include_loopback, char **out_json);

#ifdef __cplusplus
}
#endif

#endif /* RK_MDNS_H */
