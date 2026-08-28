/*
 * rk_quic — the C ABI, and the authoritative statement of it.
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
 * allocated by Rust and must come back through rk_quic_string_free. The caller
 * never calls free() on it, and Rust never frees a pointer the caller owns.
 */

#ifndef RK_QUIC_H
#define RK_QUIC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Generation of this ABI. Bumped when a signature or an ownership rule
 * changes — not when the package version changes. A caller that does not know
 * the generation it finds must refuse the library rather than guess. */
#define RK_QUIC_ABI_VERSION 2

/* Returns the generation the loaded library implements. Cannot fail. */
uint32_t rk_quic_abi_version(void);

/* Returns the library version, NUL-terminated, in static storage.
 * Ownership: not the caller's. Do not free. */
const char *rk_quic_version(void);

/* Frees a string this library allocated.
 * Ownership: takes the pointer back. Null is accepted and does nothing.
 * Passing a static pointer, a foreign pointer, or one already freed is
 * undefined behaviour. */
void rk_quic_string_free(char *s);

/* Returns the detail behind the last failure on the calling thread, or NULL
 * when there is none. Reading clears it, so a message is never reported twice.
 * Ownership: the caller's. Free with rk_quic_string_free. */
char *rk_quic_last_error(void);

/* --- the endpoint ------------------------------------------------------- */

/* Starts a QUIC/HTTP-3 endpoint serving WebTransport.
 *
 * config_json is UTF-8 JSON:
 *   {
 *     "bindAddress":         "0.0.0.0:4433",   // port 0 lets the OS choose
 *     "certificateChainPem": "-----BEGIN CERTIFICATE-----…",
 *     "privateKeyPem":       "-----BEGIN PRIVATE KEY-----…",  // PKCS#8
 *     "path":                "/rk",            // optional, default "/rk"
 *     "idleTimeoutMs":       30000             // optional, default 30000
 *   }
 * An unknown key is an error, not something ignored: a typo must not look
 * like a setting that took effect.
 *
 * On "ok" the handle is written through out_handle. On anything else
 * out_handle is untouched and rk_quic_last_error carries the detail.
 *
 * Ownership: nothing is transferred. The handle is a NAME, not a pointer —
 * a stale one is "unknownHandle", never a use-after-free. */
const char *rk_quic_server_start(const char *config_json, uint64_t *out_handle);

/* Stops an endpoint and frees everything it owns. Stopping something already
 * stopped is "notRunning", not a failure: during shutdown a double stop is
 * ordinary, and making it an error only teaches callers to ignore the result. */
const char *rk_quic_server_stop(uint64_t handle);

/* Writes the port actually bound. Worth asking after "…:0". */
const char *rk_quic_server_local_port(uint64_t handle, uint16_t *out_port);

/* Waits up to timeout_ms for the next event and writes it as JSON.
 *
 * "ok"         — an event was written; the caller now owns *out_json.
 * "wouldBlock" — the wait expired with nothing to report; *out_json is NULL.
 *
 * The two are distinct so a loop can tell "nothing happened" from "something
 * happened and was handled".
 *
 * This is a queue with a reader, not polling: nothing is asked of the network,
 * and an event arriving during the wait returns immediately. timeout_ms is
 * capped at 60000 so a caller cannot park a thread for an hour.
 *
 * Ownership: on "ok" the caller owns *out_json and frees it with
 * rk_quic_string_free. On any other status nothing was allocated.
 *
 * Event JSON carries a "kind" NAME — "sessionOpened", "sessionClosed",
 * "datagram", "streamMessage", "streamOpened", "streamData", "streamClosed",
 * "endpointError" — never a number. The three stream* kinds also carry a
 * "streamId": a session may have several exchanges open at once, and only the
 * stream says which one a reply belongs to. */
const char *rk_quic_server_poll(uint64_t handle, uint32_t timeout_ms,
                                char **out_json);

/* Sends UTF-8 to one session.
 *
 * reliable != 0 opens a unidirectional stream: ordered and retransmitted, for
 * a change that must not be lost. reliable == 0 sends a datagram: neither, for
 * the current value of something that will be sent again.
 *
 * "peerGone" means the session went away — a fact about the session rather
 * than a fault, and the signal to stop writing to it. */
const char *rk_quic_session_send(uint64_t handle, uint64_t session_id,
                                 const char *payload_utf8, uint8_t reliable);

/* Writes UTF-8 into a bidirectional stream a peer opened, without ending it.
 *
 * The unit is the stream and not the session: a browser may have several
 * exchanges open on one session at once, and only stream_id says which
 * question this answers. The ids arrive on the "streamOpened", "streamData"
 * and "streamClosed" events.
 *
 * The stream is deliberately NOT finished here — an exchange may be one
 * answer, a subscription that goes on producing, or a run reporting progress.
 * Ending it is rk_quic_stream_close, and it is a separate decision.
 *
 * "unknownHandle" means no such endpoint, or no such stream on it — closed, or
 * its session ended. "peerGone" means the write itself found the peer absent.
 * Both are facts about the peer rather than faults. */
const char *rk_quic_stream_send(uint64_t handle, uint64_t session_id,
                                uint64_t stream_id, const char *payload_utf8);

/* Finishes this side of a bidirectional stream and forgets it.
 *
 * Closing something already closed is "unknownHandle" rather than a failure,
 * for the same reason stopping a stopped endpoint is "notRunning": during
 * teardown a second close is ordinary, and making it an error only teaches
 * callers to ignore the return value. */
const char *rk_quic_stream_close(uint64_t handle, uint64_t session_id,
                                 uint64_t stream_id);

#ifdef __cplusplus
}
#endif

#endif /* RK_QUIC_H */
