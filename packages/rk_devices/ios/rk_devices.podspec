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
  s.name             = 'rk_devices'
  s.version          = '0.2.2'
  s.summary          = 'Scales, customer displays, cash drawers and MDB behind a C ABI.'
  s.description      = <<-DESC
Native part of the rk_devices Dart package. Rust behind a C ABI, linked into the
pod framework so `dart:ffi` can open it as rk_devices.framework/rk_devices.
                       DESC
  s.homepage         = 'https://github.com/0101001001001011/rk-devices'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rob Kim' => 'rk@robkim.kz' }

  s.source           = { :path => '.' }
  # One C file, so the framework has a binary at all. The Rust symbols arrive
  # through OTHER_LDFLAGS below, not through this list.
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.script_phase = {
    :name => 'Build rk_devices (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    # Before compile, not before link: the archive must exist when the pod's
    # own sources are built so the linker can see it in the same pass.
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_devices.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework carries no i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # `-force_load`, not `-l`: nothing in Objective-C or Swift references the
    # Rust symbols — Dart looks them up by name at runtime — so a plain link
    # would drop every object in the archive as unused.
    # Только `-force_load`, и это измерено, а не забыто: 2026-08-03 архив
    # слинкован с ПУСТЫМ набором фреймворков на всех трёх Apple-платформах,
    # а на macOS полученный бинарник ещё и запущен. Ни Security, ни
    # CoreFoundation, ни SystemConfiguration этому пакету не нужны.
    # Добавить фреймворк «на всякий случай» -- значит заявить зависимость,
    # которой нет.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_devices.a',
  }
  s.swift_version = '5.0'
end
