// A pod with no compiled source produces no framework binary, and with
// `use_frameworks!` there would then be nothing for Dart to open. One
// translation unit is the minimum that makes `rk_syslog.framework/rk_syslog`
// exist; the symbols that matter are pulled in from the Rust static archive by
// `-force_load` (see ../rk_syslog.podspec and ../../apple/build_rust.sh).
//
// Referenced by nothing on purpose: it is scaffolding, not an entry point.

__attribute__((used)) static const char rk_syslog_pod_marker[] = "rk_syslog";
