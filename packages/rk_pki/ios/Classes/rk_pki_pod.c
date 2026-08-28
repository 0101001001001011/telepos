// A pod with no compiled source produces no framework binary, and with
// `use_frameworks!` there would then be nothing for Dart to open. One
// translation unit is the minimum that makes `rk_pki.framework/rk_pki`
// exist; the symbols that matter are pulled in from the Rust static archive by
// `-force_load` (see ../rk_pki.podspec and ../../apple/build_rust.sh).
//
// Referenced by nothing on purpose: it is scaffolding, not an entry point.

__attribute__((used)) static const char rk_pki_pod_marker[] = "rk_pki";
