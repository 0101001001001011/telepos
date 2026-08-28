//! The loader against a real shared library.
//!
//! Unit tests cover the negative path -- a runtime that is not there. This one
//! covers the positive one, which is the half that is usually asserted in prose
//! and never run: a library that loads, exports `OrtGetApiBase`, answers
//! `GetApi` for the level we ask for, and reports a version string.
//!
//! The library is `examples/stub_ort.rs`, built as a cdylib by `cargo test`.

use std::path::PathBuf;

use rk_infer::engine::Engine;
use rk_infer::status::Status;

/// Where cargo puts the example cdylib. `current_exe` is
/// `target/<profile>/deps/<test>-<hash>`, so the examples directory is two
/// levels up and across.
fn stub_ort_path() -> PathBuf {
    let mut dir = std::env::current_exe().expect("test binary path");
    dir.pop(); // deps
    if dir.file_name().and_then(|s| s.to_str()) == Some("deps") {
        dir.pop();
    }
    dir.push("examples");

    let names: &[&str] = if cfg!(windows) {
        &["stub_ort.dll"]
    } else if cfg!(target_os = "macos") {
        &["libstub_ort.dylib"]
    } else {
        &["libstub_ort.so"]
    };

    for name in names {
        let candidate = dir.join(name);
        if candidate.exists() {
            return candidate;
        }
    }

    panic!(
        "the stub runtime was not built. Looked for {:?} in {}. \
         `cargo test` builds examples; if this fails the fixture is not being \
         built and the loader's success path is not being tested -- which is \
         worse than a red test, so this panics rather than skips.",
        names,
        dir.display()
    );
}

#[test]
fn a_runtime_that_is_there_opens_and_reports_its_version() {
    let path = stub_ort_path();
    let engine = Engine::open(Some(&path)).unwrap_or_else(|e| {
        panic!("opening {} failed: {:?}", path.display(), e);
    });

    assert_eq!(
        engine
            .runtime_version()
            .map(|v| v.to_string_lossy().into_owned())
            .as_deref(),
        Some("1.99.0-stub"),
        "the version string must come from the runtime, not from us"
    );

    // CPU is the guaranteed path, and the only provider this build claims.
    assert_eq!(engine.provider().name(), "Cpu");
    assert_eq!(engine.live_models(), 0);
    assert!(engine.check_closable().is_ok());
}

#[test]
fn a_loadable_runtime_still_cannot_run_a_model_and_says_what_is_missing() {
    // The point of the fixture is to prove the loader, not to fake an engine.
    // Everything above the loader is unimplemented, and it names the ONNX
    // Runtime entry points still to be bound instead of returning an empty
    // result that would read as "nothing detected".
    let engine = Engine::open(Some(&stub_ort_path())).expect("stub runtime opens");

    let manifest = rk_infer::manifest::Manifest::parse(
        "Model: visitor-counter\n\
         Version: 1.4.0\n\
         Task: visitorCount\n\
         Weights: w.onnx\n\
         Weights-Sha256: 0000000000000000000000000000000000000000000000000000000000000000\n\
         Weights-Bytes: 1\n\
         Input-Width: 640\n\
         Input-Height: 384\n\
         Input-Format: rgb8\n\
         Schema: 1\n\
         Min-Rk-Infer-Abi: 1\n\
         Retention-Seconds: 3600\n\
         Classes: person\n\
         Producer: test\n",
    )
    .expect("fixture manifest parses");

    let e = engine.open_session(&manifest).unwrap_err();
    assert_eq!(e.status, Status::NotImplemented);
    for expected in ["CreateSession", "CreateTensorWithDataAsOrtValue", "Run"] {
        assert!(
            e.detail.contains(expected),
            "the detail must name {}, got: {}",
            expected,
            e.detail
        );
    }
}
