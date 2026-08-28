Pod::Spec.new do |s|
  s.name             = 'rk_mdns'
  s.version          = '0.1.0'
  s.summary          = 'An mDNS responder and DNS-SD browser for Dart.'
  s.description      = <<-DESC
Native part of the rk_mdns Dart package. Rust behind a C ABI, linked into the
pod framework so `dart:ffi` can open it as rk_mdns.framework/rk_mdns.
                       DESC
  s.homepage         = 'https://github.com/0101001001001011/rk-mdns'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rob Kim' => 'rk@robkim.kz' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.script_phase = {
    :name => 'Build rk_mdns (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_mdns.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # See the iOS podspec: Dart resolves these symbols at runtime, so nothing
    # at link time references them and only `-force_load` keeps them.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_mdns.a',
  }
  s.swift_version = '5.0'
end
