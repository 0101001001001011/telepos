/*
 * rk_pki — the whole C ABI.
 *
 * Seven symbols. Operations are selected by name inside `rk_pki_call`, so a
 * new operation is not a new symbol and not a change to this file.
 *
 * Ownership, stated once:
 *   - every `char *` returned here was allocated by the library and must be
 *     released with `rk_pki_string_free`, exactly once;
 *   - the handle from `rk_pki_engine_open` must be released with
 *     `rk_pki_engine_close`, exactly once;
 *   - every `const char *` argument stays the caller's; the library borrows
 *     it for the duration of the call and does not keep it;
 *   - the string from `rk_pki_version` is static and must not be freed.
 *
 * No function here can fail by unwinding: a panic inside is caught and comes
 * back as a JSON envelope with `"kind":"nativeFault"`.
 *
 * No function here returns private key material, in any encoding.
 */

#ifndef RK_PKI_H
#define RK_PKI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* An open key store. Opaque: its layout is not part of the ABI. */
typedef struct RkPkiEngine RkPkiEngine;

/* The ABI this library was built with. A consumer checks it first. */
uint32_t rk_pki_abi_version(void);

/* The crate version. Static storage — do not free. */
const char *rk_pki_version(void);

/* Releases a string returned by this library. Null is allowed. */
void rk_pki_string_free(char *ptr);

/*
 * Opens an engine over a key store directory.
 *
 * `config_json`: {"storeDir":..., "installationId":..., "machineId":...,
 *                 "machineKind":"till"|"shopServer"|"chainServer"|
 *                               "clusterNode"|"relayClient"}
 *
 * Returns NULL on failure, writing a failure envelope to `*out_error` (which
 * the caller frees). `out_error` may be NULL.
 */
RkPkiEngine *rk_pki_engine_open(const char *config_json, char **out_error);

/* Closes an engine. Null is allowed. */
void rk_pki_engine_close(RkPkiEngine *handle);

/*
 * Runs one named operation. Returns a JSON envelope the caller frees:
 *   {"ok":true,"value":{...}} or {"ok":false,"error":{"kind":"...", ...}}
 */
char *rk_pki_call(RkPkiEngine *handle, const char *op, const char *request_json);

/* The same, for operations that need no key store: secret.hash, secret.verify,
 * selftest. */
char *rk_pki_call_stateless(const char *op, const char *request_json);

#ifdef __cplusplus
}
#endif

#endif /* RK_PKI_H */
