/*
 * rk_syslog — RFC 5424 framing, RFC 5425 delivery over TLS, bounded on-disk
 * spool.
 *
 * Hand-written so the ABI is a document rather than a by-product. It is the
 * whole contract: whatever build wiring gets chosen for the rk_* packages,
 * this is what it has to expose.
 *
 * ---------------------------------------------------------------------------
 * Rules that hold for every function here
 * ---------------------------------------------------------------------------
 *
 * FAILURE IS A RETURNED VALUE. Every call returns an int32_t from the status
 * table below. Nothing panics out of this library: each body runs inside a
 * catch, and a panic comes back as RK_SYSLOG_PANICKED (18) rather than
 * unwinding into your stack or aborting the process. Do not build the crate
 * with `panic = "abort"` — that turns the promise into a lie.
 *
 * WHO FREES WHAT
 *
 *   RkSyslogConfig*   rk_syslog_config_new   -> rk_syslog_config_free
 *   RkSyslogSd*       rk_syslog_sd_new       -> rk_syslog_sd_free
 *   RkSyslogSink*     rk_syslog_open         -> rk_syslog_close
 *   char* out_error   any call that sets one -> rk_syslog_string_free
 *   const char* return values                -> nobody; static, never freed
 *
 * Every `const char*` ARGUMENT is borrowed for the duration of the call. The
 * library copies whatever it keeps, so you may free your string as soon as
 * the call returns.
 *
 * rk_syslog_close joins the worker thread before freeing, so a closed sink
 * has finished writing what it accepted. That is what makes the freeing
 * deterministic rather than eventual.
 *
 * ENUMS CROSS BY NAME. Severity, facility and every configuration value are
 * strings. A number that shifted by one would relabel every record in the
 * journal and report no error at all. The int32_t status is a wire code, and
 * rk_syslog_status_name turns it into the name you should switch on.
 */

#ifndef RK_SYSLOG_H
#define RK_SYSLOG_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* --------------------------------------------------------------- statuses */
/* Append-only. A code, once assigned, never changes meaning and is never
 * reused. Prefer rk_syslog_status_name over these constants. */

#define RK_SYSLOG_OK                       0
#define RK_SYSLOG_NULL_ARGUMENT            1
#define RK_SYSLOG_INVALID_UTF8             2
#define RK_SYSLOG_UNKNOWN_CONFIG_KEY       3
#define RK_SYSLOG_INVALID_CONFIG_VALUE     4
#define RK_SYSLOG_MISSING_CONFIG_KEY       5
#define RK_SYSLOG_UNKNOWN_SEVERITY         6
#define RK_SYSLOG_UNKNOWN_FACILITY         7
#define RK_SYSLOG_INVALID_HEADER_FIELD     8
#define RK_SYSLOG_INVALID_STRUCTURED_DATA  9
#define RK_SYSLOG_INVALID_MESSAGE         10
#define RK_SYSLOG_QUEUE_FULL              11
#define RK_SYSLOG_SPOOL_FULL              12
#define RK_SYSLOG_SPOOL_IO                13
#define RK_SYSLOG_TRANSPORT_IO            14
#define RK_SYSLOG_TLS_CONFIG              15
#define RK_SYSLOG_TIMEOUT                 16
#define RK_SYSLOG_CLOSED                  17
#define RK_SYSLOG_PANICKED                18
#define RK_SYSLOG_INVALID_HANDLE          19
#define RK_SYSLOG_UNKNOWN_STAT            20

/* ---------------------------------------------------------------- handles */

typedef struct RkSyslogConfig RkSyslogConfig;
typedef struct RkSyslogSd RkSyslogSd;
typedef struct RkSyslogSink RkSyslogSink;

/* ------------------------------------------------------ library, statuses */

/* "MAJOR.MINOR.PATCH". Static; never free it. */
const char *rk_syslog_version(void);

/* The name of a status code, or NULL for a code this version does not
 * define — which is itself the answer a binding needs. Static; never free. */
const char *rk_syslog_status_name(int32_t code);

/* Frees a string this library handed out through an out-parameter. */
void rk_syslog_string_free(char *text);

/* ------------------------------------------------------------ name tables */

/* The RFC 5424 number for a severity or facility NAME. Returns
 * RK_SYSLOG_UNKNOWN_SEVERITY / RK_SYSLOG_UNKNOWN_FACILITY for a name this
 * version does not know — never a silent fallback to zero. */
int32_t rk_syslog_severity_value(const char *name, int32_t *out);
int32_t rk_syslog_facility_value(const char *name, int32_t *out);

/* Walks a name table. `kind` is "severity", "facility", "config_key",
 * "counter" or "status". Returns NULL past the end, and for an unknown kind.
 * Static; never free.
 *
 * The index is an iteration order for discovery, never a meaning: compare the
 * NAMES you get back with the names you know, and say so if they differ. */
const char *rk_syslog_name_at(const char *kind, int32_t index);

/* ---------------------------------------------------------- configuration */

/* NULL if the library could not allocate. */
RkSyslogConfig *rk_syslog_config_new(void);

/* Sets one named key. A key this version does not know is
 * RK_SYSLOG_UNKNOWN_CONFIG_KEY, so a typo stops the sink from opening rather
 * than leaving a default in place for someone to discover months later.
 *
 * `out_error` may be NULL. When it is not, and the call fails, it receives a
 * sentence you must free with rk_syslog_string_free. */
int32_t rk_syslog_config_set(RkSyslogConfig *config,
                             const char *key,
                             const char *value,
                             char **out_error);

void rk_syslog_config_free(RkSyslogConfig *config);

/* ------------------------------------------------------- structured data */

RkSyslogSd *rk_syslog_sd_new(void);

/* Starts an SD-ELEMENT. Parameters attach to the most recent one. */
int32_t rk_syslog_sd_element(RkSyslogSd *sd,
                             const char *sd_id,
                             char **out_error);

/* Adds a parameter. The value is escaped here, per RFC 5424 section 6.3.3 —
 * do NOT escape it yourself. */
int32_t rk_syslog_sd_param(RkSyslogSd *sd,
                           const char *name,
                           const char *value,
                           char **out_error);

/* Empties it, so one allocation can be reused between records. */
int32_t rk_syslog_sd_clear(RkSyslogSd *sd);

void rk_syslog_sd_free(RkSyslogSd *sd);

/* ------------------------------------------------------------------ sink */

/* Opens a sink. The configuration is only read and stays yours to free.
 * Everything checkable up front — the spool directory, the bound, the
 * certificates, every value — is checked here, so a mistake surfaces once at
 * startup instead of on every record. */
int32_t rk_syslog_open(RkSyslogConfig *config,
                       RkSyslogSink **out_sink,
                       char **out_error);

/* Frames a record and hands it to the worker.
 *
 * Touches no socket and no file on the calling thread: a collector that is
 * down cannot slow this down. The only failures it returns are the ones it
 * can decide here and now — a record that cannot be framed, and a hand-off
 * queue that is full.
 *
 * `epoch_micros` is microseconds since 1970-01-01T00:00:00Z and
 * `utc_offset_minutes` is east of UTC, in -1439..=1439. The clock is not read
 * here: the layer above knows the till's timezone, and this way the framing
 * has no hidden input.
 *
 * `facility_name` NULL means the sink's own facility. `msgid`,
 * `structured_data` and `message` may each be NULL. */
int32_t rk_syslog_submit(RkSyslogSink *sink,
                         const char *severity_name,
                         const char *facility_name,
                         int64_t epoch_micros,
                         int32_t utc_offset_minutes,
                         const char *msgid,
                         const RkSyslogSd *structured_data,
                         const char *message,
                         char **out_error);

/* Blocks the calling thread until everything submitted so far has reached the
 * spool, or timeout_ms elapses. Says nothing about delivery — the collector
 * may be unreachable for a week and this still returns. */
int32_t rk_syslog_flush(RkSyslogSink *sink,
                        int32_t timeout_ms,
                        char **out_error);

/* Reads a counter by name. An unknown name is RK_SYSLOG_UNKNOWN_STAT, not
 * zero: "not measured" and "measured, and none" are different answers.
 * Walk rk_syslog_name_at("counter", i) for the list. */
int32_t rk_syslog_stat(RkSyslogSink *sink,
                       const char *name,
                       int64_t *out_value,
                       char **out_error);

/* Stops accepting, waits for the worker to finish writing what it accepted,
 * then frees. Passing NULL is a no-op. */
void rk_syslog_close(RkSyslogSink *sink);

/* Provokes a panic behind the boundary so you can prove for yourself that one
 * comes back as RK_SYSLOG_PANICKED rather than taking the process with it.
 * Present in every build on purpose: a safety net nobody can test in the
 * build they ship is a safety net nobody has tested. */
int32_t rk_syslog_provoke_panic(char **out_error);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* RK_SYSLOG_H */
