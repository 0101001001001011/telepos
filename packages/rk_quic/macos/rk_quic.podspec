#
# NOT VERIFIED BY A BUILD — there is no Mac on this project. See
# ../apple/build_rust.sh for the reasoning and ../doc/native-build.md for what
# would have to be checked first on a machine that has Xcode.
#
Pod::Spec.new do |s|
  s.name             = 'rk_quic'
  s.version          = '0.2.1'
  s.summary          = 'QUIC and WebTransport for Dart over a native library.'
  s.description      = <<-DESC
Native part of the rk_quic Dart package. Rust behind a C ABI, linked into the
pod framework so `dart:ffi` can open it as rk_quic.framework/rk_quic.
                       DESC
  s.homepage         = 'https://github.com/0101001001001011/rk-quic'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rob Kim' => 'rk@robkim.kz' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.script_phase = {
    :name => 'Build rk_quic (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_quic.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # See the iOS podspec: Dart resolves these symbols at runtime, so nothing
    # at link time references them and only `-force_load` keeps them.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_quic.a',
  }
  s.swift_version = '5.0'
end
