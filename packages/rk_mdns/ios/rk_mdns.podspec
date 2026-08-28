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
  # One C file, so the framework has a binary at all. The Rust symbols arrive
  # through OTHER_LDFLAGS below, not through this list.
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.script_phase = {
    :name => 'Build rk_mdns (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    # Before compile, not before link: the archive must exist when the pod's
    # own sources are built so the linker can see it in the same pass.
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_mdns.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework carries no i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # `-force_load`, not `-l`: nothing in Objective-C or Swift references the
    # Rust symbols — Dart looks them up by name at runtime — so a plain link
    # would drop every object in the archive as unused.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_mdns.a',
  }
  s.swift_version = '5.0'
end
