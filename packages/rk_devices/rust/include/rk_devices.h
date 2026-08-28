/* rk_devices — device protocol codecs for point-of-sale peripherals.
 *
 * Scales, customer displays, cash drawers, MDB framing, and the rules for
 * resuming a partial write. The library speaks protocols; it holds no
 * deadlines, performs no I/O, sleeps never, and spawns no thread.
 *
 * -------------------------------------------------------------------------
 * Calling convention
 * -------------------------------------------------------------------------
 *
 * Every fallible function returns int32_t:
 *
 *   0  RK_DEVICES_OK             the call did what it was asked
 *   1  RK_DEVICES_FAILED         it did not; `status` holds the name of why
 *   2  RK_DEVICES_NO_STATUS_ROOM `status` was too small to hold even that,
 *                                and nothing was written
 *
 * Pass at least rk_devices_status_capacity() bytes for `status` and the
 * third value cannot occur.
 *
 * -------------------------------------------------------------------------
 * Enumerations cross by name, never by number
 * -------------------------------------------------------------------------
 *
 * Every protocol, model, operation, pin, address, wire, verdict, frame kind
 * and status is a NUL-terminated UTF-8 name in both directions. A number
 * changes meaning the moment a case is inserted into the middle of a list;
 * a name does not. The status names are:
 *
 *   "ok" "unknown_name" "unsupported_operation" "buffer_too_small"
 *   "invalid_argument" "invalid_utf8" "out_of_range" "panic"
 *
 * -------------------------------------------------------------------------
 * Memory: the caller owns everything
 * -------------------------------------------------------------------------
 *
 * This library allocates nothing that crosses the boundary, so there is no
 * free function and nothing to leak. Every result is written into a buffer
 * the caller supplies. When a buffer is too short the call reports
 * "buffer_too_small" AND writes the required length into `*out_len` first,
 * so the caller can size and retry instead of guessing.
 *
 * -------------------------------------------------------------------------
 * Failures are values
 * -------------------------------------------------------------------------
 *
 * Every entry point catches panics. A bug inside this library becomes the
 * status name "panic"; nothing unwinds into the calling stack and nothing
 * aborts. The crate refuses to compile under panic=abort.
 * rk_devices_provoke_panic_for_test() exists so a consumer can prove this
 * rather than assume it.
 */

#ifndef RK_DEVICES_H
#define RK_DEVICES_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RK_DEVICES_OK             0
#define RK_DEVICES_FAILED         1
#define RK_DEVICES_NO_STATUS_ROOM 2

/* ---- meta ------------------------------------------------------------- */

uint32_t rk_devices_abi_version(void);
size_t   rk_devices_status_capacity(void);

int32_t rk_devices_version(char *out, size_t cap,
                           char *status, size_t status_cap);

/* Always fails with the status name "panic". For tests only. */
int32_t rk_devices_provoke_panic_for_test(char *status, size_t status_cap);

/* ---- partial writes --------------------------------------------------- */
/* wire_name: "serial" | "socket" | "usb_raw"
 * report_name: "accepted" | "failed"
 * out_action: "done" | "continue" | "unknown"
 *
 * Only "serial" reports how many bytes it accepted. A partial count claimed
 * for "socket" or "usb_raw" is refused with "invalid_argument" rather than
 * believed: those transports cannot produce one, and resuming from an
 * invented offset sends the wrong bytes. */

int32_t rk_devices_wire_reports_partial_writes(const char *wire_name,
                                               uint8_t *out,
                                               char *status, size_t status_cap);

int32_t rk_devices_wire_resolve(const char *wire_name,
                                size_t total,
                                const char *report_name,
                                size_t accepted,
                                char *out_action, size_t action_cap,
                                size_t *out_offset,
                                char *status, size_t status_cap);

/* ---- scales ----------------------------------------------------------- */
/* protocol_name: "generic" | "cas" | "massa_k"
 * out_kind:      "reading" | "incomplete" | "garbage"
 * out_unit:      "kg" | "g" | "lb"
 * out_stability: "stable" | "unstable" | "overload" | "underload"
 * out_measure:   "gross" | "net" | "unknown"
 *
 * The weight is (*out_scaled / 10^*out_decimals) in *out_unit — an integer
 * and an exponent, never a float, because the number is about to be
 * multiplied by a price. No unit conversion is performed anywhere. */

int32_t rk_devices_scale_weight_request(const char *protocol_name,
                                        uint8_t *out, size_t cap,
                                        size_t *out_len,
                                        char *status, size_t status_cap);

int32_t rk_devices_scale_tare_request(const char *protocol_name,
                                      uint8_t *out, size_t cap,
                                      size_t *out_len,
                                      char *status, size_t status_cap);

int32_t rk_devices_scale_parse(const char *protocol_name,
                               const uint8_t *data, size_t len,
                               char *out_kind, size_t kind_cap,
                               int64_t *out_scaled,
                               uint32_t *out_decimals,
                               char *out_unit, size_t unit_cap,
                               char *out_stability, size_t stability_cap,
                               char *out_measure, size_t measure_cap,
                               size_t *out_consumed,
                               char *status, size_t status_cap);

/* The settling rule. The caller allocates the state, the caller frees it;
 * this library keeps no clock and never waits. `budget_ms` bounds the wait
 * in TIME, not in attempts.
 *
 * heard_name:  "reading" | "noise" | "silence"
 * out_verdict: "settled" | "not_yet" | "expired" | "no_answer"
 *
 * "expired" and "no_answer" are different facts: a scale that answered and
 * never settled, versus a scale that never said anything. Reporting both as
 * one timeout sends an operator to look at the pan when the cable is out. */

size_t rk_devices_stabilizer_size(void);
size_t rk_devices_stabilizer_align(void);

int32_t rk_devices_stabilizer_init(uint8_t *state,
                                   uint32_t needed_repeats,
                                   uint32_t budget_ms,
                                   char *status, size_t status_cap);

int32_t rk_devices_stabilizer_offer(uint8_t *state,
                                    uint32_t elapsed_ms,
                                    const char *heard_name,
                                    int64_t scaled,
                                    uint32_t decimals,
                                    const char *stability_name,
                                    char *out_verdict, size_t verdict_cap,
                                    char *status, size_t status_cap);

/* ---- customer displays ------------------------------------------------ */
/* model_name: "led8" | "vfd20" | "lcd2x20"
 * op_name:    "reset" | "clear" | "home" | "display_on" | "display_off"
 *             | "blink" | "set_brightness" | "set_cursor" | "write_line"
 *
 * `text` is UTF-8 and is read only by "write_line". *out_substitutions is
 * the number of characters that had no byte in the model's code page —
 * CP866 has no Kazakh or Kyrgyz letters and no tenge sign, so a non-zero
 * count means the customer is being shown something else. */

int32_t rk_devices_display_geometry(const char *model_name,
                                    uint32_t *out_lines,
                                    uint32_t *out_columns,
                                    char *status, size_t status_cap);

int32_t rk_devices_display_encode(const char *model_name,
                                  const char *op_name,
                                  uint32_t line,
                                  uint32_t column,
                                  uint32_t brightness,
                                  const uint8_t *text, size_t text_len,
                                  uint8_t *out, size_t cap, size_t *out_len,
                                  size_t *out_substitutions,
                                  char *status, size_t status_cap);

/* ---- cash drawers ----------------------------------------------------- */
/* model_name: "escpos_kick"
 * pin_name:   "pin2" | "pin5"
 * reporting:  "cannot_report" — the kick wire is one-directional, and a
 *             caller must not claim the drawer opened. */

int32_t rk_devices_drawer_pulse(const char *model_name,
                                const char *pin_name,
                                uint32_t on_ms, uint32_t off_ms,
                                uint8_t *out, size_t cap, size_t *out_len,
                                char *status, size_t status_cap);

int32_t rk_devices_drawer_reporting(const char *model_name,
                                    char *out, size_t cap,
                                    char *status, size_t status_cap);

int32_t rk_devices_drawer_default_pulse_ms(uint32_t *out_on_ms,
                                           uint32_t *out_off_ms,
                                           char *status, size_t status_cap);

/* ---- MDB -------------------------------------------------------------- */
/* address_name: "coin_changer" | "cashless_1" | "comms_gateway"
 *             | "bill_validator" | "cashless_2"
 * out_kind:     "block" | "ack" | "nak" | "ret" | "incomplete"
 *             | "bad_checksum"
 *
 * Words are nine bits wide in a uint16_t; bit 8 is the mode bit. The
 * response window and bit time are published as numbers to configure a
 * bridge microcontroller with — this library never waits, so it cannot
 * enforce them. The address and command bytes are transcribed from
 * secondary sources and have never met a device; rk_devices_mdb_encode_raw
 * exists so a caller with the real standard is not blocked by that. */

uint32_t rk_devices_mdb_response_window_ms(void);
uint32_t rk_devices_mdb_bit_time_us(void);
uint16_t rk_devices_mdb_mode_bit(void);

int32_t rk_devices_mdb_command_byte(const char *address_name,
                                    const char *command_name,
                                    uint8_t *out,
                                    char *status, size_t status_cap);

int32_t rk_devices_mdb_checksum(const uint8_t *data, size_t len,
                                uint8_t *out,
                                char *status, size_t status_cap);

int32_t rk_devices_mdb_encode(const char *address_name,
                              const char *command_name,
                              const uint8_t *data, size_t data_len,
                              uint16_t *out, size_t cap, size_t *out_len,
                              char *status, size_t status_cap);

int32_t rk_devices_mdb_encode_raw(uint8_t command,
                                  const uint8_t *data, size_t data_len,
                                  uint16_t *out, size_t cap, size_t *out_len,
                                  char *status, size_t status_cap);

int32_t rk_devices_mdb_decode(const uint16_t *words, size_t words_len,
                              char *out_kind, size_t kind_cap,
                              uint8_t *out_payload, size_t payload_cap,
                              size_t *out_payload_len,
                              size_t *out_consumed,
                              char *status, size_t status_cap);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* RK_DEVICES_H */
