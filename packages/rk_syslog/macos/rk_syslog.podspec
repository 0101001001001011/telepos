#
# Verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2 / rustc 1.97.1:
# macosx (arm64+x86_64), iphoneos (arm64) and iphonesimulator (arm64+x86_64)
# each link a C probe against the OTHER_LDFLAGS below, in BOTH Release and
# Debug, and the macOS binaries were run through the C ABI. Before that day not
# one line here had ever been compiled.
#
# The Apple build is now gated by the `packages-apple` job in the root CI of
# the monorepo. See ../apple/build_rust.sh and ../doc/native-build.md.
#
Pod::Spec.new do |s|
  s.name             = 'rk_syslog'
  s.version          = '0.2.2'
  s.summary          = 'RFC 5424 framing, RFC 5425 delivery over TLS and a bounded on-disk spool.'
  s.description      = <<-DESC
Native part of the rk_syslog Dart package. Rust behind a C ABI, linked into the
pod framework so `dart:ffi` can open it as rk_syslog.framework/rk_syslog.
                       DESC
  s.homepage         = 'https://github.com/0101001001001011/rk-syslog'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rob Kim' => 'rk@robkim.kz' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.script_phase = {
    :name => 'Build rk_syslog (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_syslog.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # See the iOS podspec: Dart resolves these symbols at runtime, so nothing
    # at link time references them and only `-force_load` keeps them.
    # Только `-force_load`, и это измерено, а не забыто: 2026-08-03 архив
    # слинкован с ПУСТЫМ набором фреймворков на всех трёх Apple-платформах,
    # а на macOS полученный бинарник ещё и запущен. Ни Security, ни
    # CoreFoundation, ни SystemConfiguration этому пакету не нужны.
    # Добавить фреймворк «на всякий случай» -- значит заявить зависимость,
    # которой нет.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_syslog.a',
  }
  s.swift_version = '5.0'
end
