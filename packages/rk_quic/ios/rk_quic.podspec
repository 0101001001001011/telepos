#
# NOT VERIFIED BY A BUILD — there is no Mac on this project. See
# ../apple/build_rust.sh for the reasoning and ../doc/native-build.md for what
# would have to be checked first on a machine that has Xcode.
#
Pod::Spec.new do |s|
  s.name             = 'rk_quic'
  s.version          = '0.2.2'
  s.summary          = 'QUIC and WebTransport for Dart over a native library.'
  s.description      = <<-DESC
Native part of the rk_quic Dart package. Rust behind a C ABI, linked into the
pod framework so `dart:ffi` can open it as rk_quic.framework/rk_quic.
                       DESC
  s.homepage         = 'https://github.com/0101001001001011/rk-quic'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rob Kim' => 'rk@robkim.kz' }

  s.source           = { :path => '.' }
  # One C file, so the framework has a binary at all. The Rust symbols arrive
  # through OTHER_LDFLAGS below, not through this list.
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.script_phase = {
    :name => 'Build rk_quic (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    # Before compile, not before link: the archive must exist when the pod's
    # own sources are built so the linker can see it in the same pass.
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_quic.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework carries no i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # `-force_load`, not `-l`: nothing in Objective-C or Swift references the
    # Rust symbols — Dart looks them up by name at runtime — so a plain link
    # would drop every object in the archive as unused.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_quic.a',
  }
  s.swift_version = '5.0'
end
