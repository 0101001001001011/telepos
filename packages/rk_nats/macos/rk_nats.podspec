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
  s.name             = 'rk_nats'
  s.version          = '0.2.2'
  s.summary          = 'NATS and JetStream with an enforced durability contract.'
  s.description      = <<-DESC
Native part of the rk_nats Dart package. Rust behind a C ABI, linked into the
pod framework so `dart:ffi` can open it as rk_nats.framework/rk_nats.
                       DESC
  s.homepage         = 'https://github.com/0101001001001011/rk-nats'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rob Kim' => 'rk@robkim.kz' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.script_phase = {
    :name => 'Build rk_nats (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../apple/build_rust.sh"',
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/librk_nats.a'],
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # See the iOS podspec: Dart resolves these symbols at runtime, so nothing
    # at link time references them and only `-force_load` keeps them.
    # `-framework Security -framework CoreFoundation`, и это не суеверие.
    #
    # Rust-staticlib не несёт LC_LINKER_OPTION -- `otool -l` по архиву не
    # показывает ни одного -- поэтому директивы линковки, которые cargo
    # применил бы сам при сборке бинарника, теряются в тот момент, когда
    # линкует Xcode. Их приходится назвать здесь.
    #
    # Цепочка: async-nats -> rustls-native-certs 0.8.4 -> security-framework.
    # Измерено 2026-08-03: без Security -- 289 неразрешённых символов
    # (_SecKeychainCopyDomainSearchList, _CMSDecoderCreate,
    # _AuthorizationCreate, _SecTrustSettingsCopyCertificates); без
    # CoreFoundation -- 88 (_CFArrayCreate, _CFRelease, _CFDataGetBytePtr),
    # и ссылается на них rustls_native_certs::macos::load_native_certs.
    # Ни один из двух по отдельности не спасает.
    #
    # В ios/rk_nats.podspec этого НЕТ намеренно: на iOS security-framework
    # вообще отсутствует в графе зависимостей -- `cargo tree -i
    # security-framework --target aarch64-apple-ios` печатает пустоту, --
    # потому что keychain-пути там нет и крейт уходит в файловую ветку.
    # Флаг там был бы фреймворком, которому в архиве не отвечает ни один
    # символ.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/librk_nats.a -framework Security -framework CoreFoundation',
  }
  s.swift_version = '5.0'
end
