/*
 * rk_infer -- C ABI.
 *
 * This header is the contract. The Rust side implements it, the Dart binding
 * consumes it, and neither is free to change it without a major version.
 *
 * Three rules run through every declaration below.
 *
 *  1. A failure is a returned value (I144). No entry point panics, aborts, or
 *     lets an exception out of a foreign stack. Every fallible call returns a
 *     status; a Rust panic inside is caught at the boundary and reported as
 *     the status "NativeFault".
 *
 *  2. An enum crosses by name, never by number (I147). A status, a pixel
 *     format, a task, an execution provider -- each is a NUL-terminated ASCII
 *     name in both directions. Inserting a case in the middle of a Rust enum
 *     therefore cannot silently change what an older peer understands, because
 *     no ordinal ever crosses.
 *
 *  3. Every allocation has exactly one owner and one deallocator (I146),
 *     named in the comment above the function that produces it. A frame buffer
 *     is megabytes; there is no arrangement here under which both sides
 *     believe someone else will free it.
 */

#ifndef RK_INFER_H
#define RK_INFER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* --------------------------------------------------------------------------
 * ABI version
 *
 * Bumped whenever a signature or a struct layout below changes. The Dart
 * binding refuses to talk to a library reporting a different value rather than
 * guessing, because a mismatched layout is read as plausible garbage.
 * -------------------------------------------------------------------------- */
#define RK_INFER_ABI_VERSION 1u

uint32_t rk_infer_abi_version(void);

/* --------------------------------------------------------------------------
 * Status and detail
 *
 * Every fallible entry point returns `const char*`:
 *   NULL      -- the call succeeded.
 *   non-NULL  -- a static, never-freed, NUL-terminated status NAME,
 *                for example "ModelChecksumMismatch". Do not free it.
 *
 * `detail_out` is optional and may be NULL. When it is not NULL it is always
 * written: NULL on success, otherwise an owned UTF-8 string that the CALLER
 * frees with rk_infer_string_free. The detail names what was wrong -- which
 * key was missing, which path was tried -- and never contains pixel data.
 * -------------------------------------------------------------------------- */

/* Frees a string this library handed out through a `char**` out-parameter.
 * Owner: the caller. Passing NULL is allowed and does nothing. */
void rk_infer_string_free(char *s);

/* The full set of status names this build can return, as a single
 * comma-separated static string. Lets a binding assert at start-up that it
 * knows every name the library can produce, instead of discovering an unknown
 * one in production. Static, never freed. */
const char *rk_infer_status_names(void);

/* --------------------------------------------------------------------------
 * Frames -- I146, stated exactly
 *
 *   Allocated by:   rk_infer_frame_new, in Rust, one Vec<u8>.
 *   Freed by:       rk_infer_frame_free, in Rust, and nowhere else.
 *   Dart:           never allocates and never frees frame pixels. It receives
 *                   a write pointer, memcpys into it, and drops the view.
 *   rk_infer_run:   BORROWS the frame for the duration of the call. Ownership
 *                   does not move. Freeing a frame while a run holds it
 *                   returns "FrameInUse" rather than pulling memory out from
 *                   under the engine.
 *
 * There is deliberately no function that reads pixels back out. The write
 * pointer from rk_infer_frame_new points into the frame's own buffer and is
 * valid until rk_infer_frame_free; it exists so the caller can fill the frame,
 * which is the only direction pixels are ever meant to travel.
 * -------------------------------------------------------------------------- */

typedef struct RkInferFrame RkInferFrame;

/* Allocates a frame sized for `width` x `height` in `pixel_format_name`
 * (one of the names in rk_infer_pixel_format_names).
 *
 * On success writes:
 *   *out        -- the frame handle, freed by rk_infer_frame_free.
 *   *write_out  -- a pointer to the frame's pixel buffer, writable, valid
 *                  until the frame is freed. NOT owned by the caller.
 *   *bytes_out  -- the buffer's exact length.
 *
 * Fails with "UnsupportedPixelFormat" or "InvalidArgument". */
const char *rk_infer_frame_new(uint32_t width,
                               uint32_t height,
                               const char *pixel_format_name,
                               RkInferFrame **out,
                               uint8_t **write_out,
                               size_t *bytes_out,
                               char **detail_out);

/* The buffer length, for a caller that kept only the handle. */
size_t rk_infer_frame_bytes(const RkInferFrame *frame);

/* Frees the frame and its pixels. Owner: whoever called rk_infer_frame_new.
 * Passing NULL is allowed and does nothing. Returns "FrameInUse" and frees
 * nothing if a run currently borrows this frame. */
const char *rk_infer_frame_free(RkInferFrame *frame);

/* The pixel format names this build accepts, comma-separated. Static. */
const char *rk_infer_pixel_format_names(void);

/* The task names this build recognises, comma-separated. Static. */
const char *rk_infer_task_names(void);

/* --------------------------------------------------------------------------
 * Engine
 *
 * The engine is the embedded C++ inference runtime -- ONNX Runtime as the
 * baseline. This library does not contain it and does not download it: it
 * opens a shared library that is already on the machine, put there by the same
 * signed apt channel that delivers the models (see doc/models.md).
 *
 * If it is not there, that is "EngineUnavailable" with the tried paths in the
 * detail. It is never a crash and never a silent no-op.
 * -------------------------------------------------------------------------- */

typedef struct RkInferEngine RkInferEngine;

/* Opens the inference runtime.
 *   library_path -- an explicit path, or NULL to try the platform's default
 *                   names in order.
 * Owner of *out: the caller, freed with rk_infer_engine_close. */
const char *rk_infer_engine_open(const char *library_path,
                                 RkInferEngine **out,
                                 char **detail_out);

/* Closes the engine and unloads the runtime. Frees *out from
 * rk_infer_engine_open. NULL is allowed. Returns "EngineBusy" and frees
 * nothing while models loaded from it are still alive. */
const char *rk_infer_engine_close(RkInferEngine *engine);

/* The runtime's own version string, borrowed from the runtime, valid until
 * the engine is closed. NULL if the runtime did not supply one. */
const char *rk_infer_engine_runtime_version(const RkInferEngine *engine);

/* The execution provider actually in use, by NAME: "Cpu" always works and is
 * the guaranteed path; anything else is an accelerator that was found, not one
 * that was assumed. Borrowed, valid until the engine is closed. */
const char *rk_infer_engine_provider(const RkInferEngine *engine);

/* --------------------------------------------------------------------------
 * Models
 *
 * A model is a manifest plus weights, both delivered by apt. Loading verifies
 * the manifest before it verifies the weights, and verifies the weights before
 * it hands anything to the runtime. A model whose SHA-256 does not match the
 * manifest does not load -- silent degradation is worse than a refusal here,
 * because weights read in the wrong layout do not fail, they produce a
 * confident wrong answer.
 * -------------------------------------------------------------------------- */

typedef struct RkInferModel RkInferModel;

/* Loads and verifies the model named by `manifest_path`.
 *
 *   pinned_version -- the version this terminal is pinned to, or NULL to
 *                     accept whatever the manifest says. A mismatch is
 *                     "ModelPinMismatch": a model must not change under a
 *                     till because a repository moved on.
 *
 * Owner of *out: the caller, freed with rk_infer_model_unload. */
const char *rk_infer_model_load(RkInferEngine *engine,
                                const char *manifest_path,
                                const char *pinned_version,
                                RkInferModel **out,
                                char **detail_out);

/* Frees the model and releases the runtime session. Owner: whoever called
 * rk_infer_model_load. NULL is allowed. */
void rk_infer_model_unload(RkInferModel *model);

/* Metadata, all borrowed and valid until unload. */
const char *rk_infer_model_name(const RkInferModel *model);
const char *rk_infer_model_version(const RkInferModel *model);
const char *rk_infer_model_task(const RkInferModel *model);   /* task NAME */
const char *rk_infer_model_input_format(const RkInferModel *model);
uint32_t rk_infer_model_input_width(const RkInferModel *model);
uint32_t rk_infer_model_input_height(const RkInferModel *model);

/* How long a result derived from this model may be kept, in seconds.
 * Always finite and always greater than zero: a manifest without a retention,
 * or with an unbounded one, fails to load (I93, I94). */
uint32_t rk_infer_model_retention_seconds(const RkInferModel *model);

/* --------------------------------------------------------------------------
 * Running
 *
 * What comes back is a structured outcome: class names, confidences, boxes in
 * normalised coordinates, and a retention deadline. Pixels are not among them,
 * and there is no accessor here that could return them.
 * -------------------------------------------------------------------------- */

typedef struct RkInferDetection {
  /* Class NAME, borrowed from the model's class table, valid until unload. */
  const char *class_name;
  double confidence; /* 0.0 .. 1.0 */
  /* Normalised 0.0 .. 1.0 against the input frame, so the caller never needs
   * the frame to interpret them. */
  double x;
  double y;
  double w;
  double h;
} RkInferDetection;

typedef struct RkInferOutcome RkInferOutcome;

/* Runs one frame. Borrows both `model` and `frame` for the call.
 * Owner of *out: the caller, freed with rk_infer_outcome_free. */
const char *rk_infer_run(RkInferModel *model,
                         RkInferFrame *frame,
                         RkInferOutcome **out,
                         char **detail_out);

size_t rk_infer_outcome_len(const RkInferOutcome *outcome);

/* Borrowed, valid until rk_infer_outcome_free. NULL if `index` is out of
 * range -- out of range is not a crash. */
const RkInferDetection *rk_infer_outcome_at(const RkInferOutcome *outcome,
                                            size_t index);

/* Unix seconds after which this result must be deleted or anonymised.
 * Always in the future of the run and always finite. */
uint64_t rk_infer_outcome_retain_until(const RkInferOutcome *outcome);

/* Frees the outcome. Owner: whoever called rk_infer_run. NULL is allowed. */
void rk_infer_outcome_free(RkInferOutcome *outcome);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* RK_INFER_H */
