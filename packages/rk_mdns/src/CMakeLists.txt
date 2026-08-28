# Where CMake and cargo meet — for Windows and Linux only.
#
# Android does NOT come through here. It used to on a sibling package, and the
# result was an APK that built green and shipped with no library in it; the
# whole account is in `android/build.gradle`. Apple does not come through here
# either: a pod built with `use_frameworks!` needs the artefact *inside* the
# framework, so it goes through `apple/build_rust.sh` from a podspec script
# phase.
#
# The mapping below is a moving part: CMake names a platform, Rust names a
# target triple, and nothing keeps the two lists in step. An unmapped platform
# is a hard error here rather than a link failure three steps later.

cmake_minimum_required(VERSION 3.10)

project(rk_mdns_library VERSION 0.1.0 LANGUAGES NONE)

if(WIN32)
  set(RK_TRIPLE "x86_64-pc-windows-msvc")
  set(RK_LIB_FILE "rk_mdns.dll")
elseif(ANDROID)
  message(FATAL_ERROR
    "rk_mdns: Android must not reach this file. It builds through "
    "android/build.gradle (task rkMdnsCargoBuild) because AGP never invokes a "
    "CMake custom target — see the comment at the top of that file.")
elseif(APPLE)
  message(FATAL_ERROR
    "rk_mdns: Apple must not reach this file. It builds through "
    "apple/build_rust.sh from the podspec script phase, because the artefact "
    "has to land inside the pod framework.")
elseif(UNIX)
  set(RK_TRIPLE "x86_64-unknown-linux-gnu")
  set(RK_LIB_FILE "librk_mdns.so")
else()
  message(FATAL_ERROR "rk_mdns: no Rust target triple for this platform")
endif()

set(RK_CARGO_DIR "${CMAKE_CURRENT_BINARY_DIR}/cargo")
set(RK_OUT "${RK_CARGO_DIR}/${RK_TRIPLE}/release/${RK_LIB_FILE}")
set(RK_CRATE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust")

# Globbed, not listed. A hand-written DEPENDS silently stops covering a source
# added later, and the failure mode is the worst one available: the build is
# green and the library is stale. Measured on a sibling package 2026-08-03,
# where the list named four of eight sources and `touch src/server_ffi.rs` ran
# cargo not at all.
file(GLOB_RECURSE RK_CRATE_SOURCES CONFIGURE_DEPENDS "${RK_CRATE_DIR}/src/*.rs")

add_custom_command(
  OUTPUT "${RK_OUT}"
  COMMAND ${CMAKE_COMMAND} -E env
          cargo build --release
          --target ${RK_TRIPLE}
          --target-dir "${RK_CARGO_DIR}"
  WORKING_DIRECTORY "${RK_CRATE_DIR}"
  DEPENDS "${RK_CRATE_DIR}/Cargo.toml" ${RK_CRATE_SOURCES}
  COMMENT "cargo build --release --target ${RK_TRIPLE}"
  VERBATIM
)

add_custom_target(rk_mdns_cargo ALL DEPENDS "${RK_OUT}")

# The Flutter tool copies everything listed in `<package>_bundled_libraries`
# next to the runner (Windows) or into `bundle/lib/` (Linux). Unlike AGP, it
# takes a path and does not need to understand the target that produced it —
# which is exactly why this route works on these two platforms and not on
# Android.
set(RK_LIBRARY_PATH "${RK_OUT}" PARENT_SCOPE)
