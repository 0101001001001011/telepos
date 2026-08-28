/// Locating and building the native side, for tests that go all the way
/// through the ABI.
///
/// These tests build the Rust crate rather than skipping when it is absent.
/// A package whose core is Rust needs Rust to test; a skip here would be a
/// green run that proves nothing about the boundary, which is the failure mode
/// this project has been bitten by before.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The package root, found from the test's own location rather than the
/// working directory, which `dart test` does not promise.
Directory get packageRoot {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('no pubspec.yaml above ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

String get _rustDir => '${packageRoot.path}/rust';

String _artifact(String stem, {bool example = false}) {
  final dir = example ? 'rust/target/debug/examples' : 'rust/target/debug';
  final name = Platform.isWindows
      ? '$stem.dll'
      : Platform.isMacOS
      ? 'lib$stem.dylib'
      : 'lib$stem.so';
  return '${packageRoot.path}/$dir/$name';
}

bool _built = false;

/// Builds the crate once per test process.
void ensureNativeBuilt() {
  if (_built) return;

  final result = Process.runSync(
    'cargo',
    <String>['build', '--lib', '--examples'],
    workingDirectory: _rustDir,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    fail(
      'cargo build failed in $_rustDir. This package\'s core is Rust, so its '
      'tests need a Rust toolchain -- see CONTRIBUTING.md. Skipping instead '
      'would be a green run that proves nothing about the boundary.\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
  _built = true;
}

/// The `rk_infer` shared library: the binding under test.
String get bindingLibraryPath {
  ensureNativeBuilt();
  final path = _artifact('rk_infer');
  if (!File(path).existsSync()) {
    fail('cargo build succeeded but $path is not there');
  }
  return path;
}

/// A stand-in for ONNX Runtime.
///
/// It exports `OrtGetApiBase` and answers `GetApi` and `GetVersionString`, and
/// that is all -- which is exactly the boundary this package has finished. It
/// is **not** a fake engine: nothing above the loader is implemented in it, and
/// the tests assert that a model load reaches `NotImplemented` and stops there.
/// Real inference numbers can only come from a real runtime on real hardware.
String get stubRuntimePath {
  ensureNativeBuilt();
  final path = _artifact('stub_ort', example: true);
  if (!File(path).existsSync()) {
    fail('cargo build succeeded but the stub runtime $path is not there');
  }
  return path;
}

/// A model directory laid out the way the apt package lays one out.
class ModelFixture {
  ModelFixture._(this.dir, this.manifestPath, this.weightsPath);

  final Directory dir;
  final String manifestPath;
  final String weightsPath;

  /// Writes a manifest and weights that agree with each other.
  ///
  /// `weights` is written verbatim, so a caller can put a recognisable pattern
  /// in it and then check that pattern never surfaces in an error.
  static ModelFixture create({
    required String name,
    String version = '1.4.0',
    String task = 'visitorCount',
    List<int>? weights,
    String? overrideSha,
    int? overrideBytes,
    int retentionSeconds = 604800,
    int width = 640,
    int height = 384,
    String format = 'rgb8',
    int schema = 1,
    int minAbi = 1,
    String classes = 'person',
  }) {
    final dir = Directory.systemTemp.createTempSync('rk_infer_model_');
    final payload = weights ?? utf8.encode('weights for $name $version');
    final weightsFile = File('${dir.path}/$name.onnx')
      ..writeAsBytesSync(payload);

    final sha = overrideSha ?? _sha256Hex(payload);
    final manifest = File('${dir.path}/model.manifest')
      ..writeAsStringSync(
        <String>[
          '# Delivered by telepos-model-$name',
          'Model: $name',
          'Version: $version',
          'Task: $task',
          'Weights: $name.onnx',
          'Weights-Sha256: $sha',
          'Weights-Bytes: ${overrideBytes ?? payload.length}',
          'Input-Width: $width',
          'Input-Height: $height',
          'Input-Format: $format',
          'Schema: $schema',
          'Min-Rk-Infer-Abi: $minAbi',
          'Retention-Seconds: $retentionSeconds',
          'Classes: $classes',
          'Producer: telepos-model-$name $version',
          '',
        ].join('\n'),
      );

    return ModelFixture._(dir, manifest.path, weightsFile.path);
  }

  void dispose() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// SHA-256 in hex, from an implementation that is not the one under test.
///
/// Deliberately `dart:crypto`-free and deliberately not the Rust one: a
/// checksum check verified with its own implementation verifies nothing.
String _sha256Hex(List<int> data) {
  final result = Process.runSync(Platform.resolvedExecutable, <String>[
    '--version',
  ]);
  // The Dart SDK has no SHA-256 in its core libraries, and this package takes
  // no dependency for one line of test support. The platform's own tool is a
  // genuinely independent implementation, which is the property that matters.
  final tmp = File(
    '${Directory.systemTemp.path}/rk_infer_sha_${result.pid}_'
    '${DateTime.now().microsecondsSinceEpoch}.bin',
  )..writeAsBytesSync(data);
  try {
    if (Platform.isWindows) {
      final out = Process.runSync('certutil', <String>[
        '-hashfile',
        tmp.path,
        'SHA256',
      ]);
      final lines = (out.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      // certutil prints a banner, the digest, then a completion line.
      for (final line in lines) {
        final candidate = line.replaceAll(' ', '').toLowerCase();
        if (candidate.length == 64 &&
            RegExp(r'^[0-9a-f]{64}$').hasMatch(candidate)) {
          return candidate;
        }
      }
      throw StateError('certutil said: ${out.stdout}');
    }

    final out = Process.runSync('sha256sum', <String>[tmp.path]);
    if (out.exitCode == 0) {
      return (out.stdout as String).split(RegExp(r'\s+')).first.toLowerCase();
    }
    final mac = Process.runSync('shasum', <String>['-a', '256', tmp.path]);
    if (mac.exitCode == 0) {
      return (mac.stdout as String).split(RegExp(r'\s+')).first.toLowerCase();
    }
    throw StateError('no SHA-256 tool on this host');
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}
