/// Section 21 as a structural check, not a promise.
///
/// The rule is that the contract has **no method that returns a raw frame,
/// writes one to disk, or opens a socket**. A rule like that decays into a
/// comment unless something fails when it is broken, so this walks the entire
/// public surface with `dart:mirrors` and fails if any declaration's type --
/// transitively, through generics -- could carry bytes.
///
/// # How to check that this test still bites
///
/// Add one line to `lib/src/contract.dart`, inside `InferenceOutput`:
///
/// ```dart
/// Uint8List get frameBytes => Uint8List(0);
/// ```
///
/// (plus `import 'dart:typed_data';`). `grep -n frameBytes lib/src/contract.dart`
/// to confirm the edit actually landed -- a mutation that silently fails to
/// apply proves nothing -- then `dart test test/no_raw_frame_test.dart`. It
/// must go red naming `InferenceOutput.frameBytes`. Remove the line and it
/// must go green again. This was done on 2026-07-31 and is recorded in the
/// report.
@TestOn('vm')
library;

import 'dart:mirrors';

import 'package:test/test.dart';

// Imported for its side effect on the mirror system: a library has to be
// loaded before `currentMirrorSystem()` can find it. This is the only import
// a consumer needs, and it is the only one this test takes -- the surface
// below is derived from its `export` directives.
// ignore: unused_import
import 'package:rk_infer/rk_infer.dart';

/// Types that are, or can hold, raw bytes.
///
/// `TransferableTypedData` is here as a *return*. As a parameter it is exactly
/// right -- it is how a frame is moved in, and it detaches the sender's
/// buffers when it is built. Handing one back would undo that.
const Set<String> byteBearingTypes = <String>{
  // dart:typed_data
  'TypedData',
  'ByteData',
  'ByteBuffer',
  'Uint8List',
  'Uint8ClampedList',
  'Int8List',
  'Uint16List',
  'Int16List',
  'Uint32List',
  'Int32List',
  'Uint64List',
  'Int64List',
  'Float32List',
  'Float64List',
  'Int32x4List',
  'Float32x4List',
  'Float64x2List',
  // dart:isolate
  'TransferableTypedData',
  // dart:ffi -- a pointer is a frame with extra steps
  'Pointer',
  'Array',
  'NativeType',
  'Struct',
  'Union',
  'Opaque',
  'DynamicLibrary',
  'NativeFrame',
  'NativeDetection',
  'RkInferLib',
  'NativeEngineSession',
  // dart:io -- the "writes one to disk, opens a socket" half of the rule
  'File',
  'RandomAccessFile',
  'IOSink',
  'Socket',
  'RawSocket',
  'Directory',
  'HttpClient',
};

/// Types that defeat the check by being able to hold anything.
///
/// A getter returning `dynamic` is not obviously a leak, and that is the
/// problem: it means this test can no longer tell. Refuse them on the public
/// surface so the check keeps its teeth.
const Set<String> opaqueEscapeHatches = <String>{
  'dynamic',
  'Object',
  'Function',
};

/// Element types that make a collection byte-shaped.
const Set<String> byteElementTypes = <String>{'int'};

const Set<String> collectionTypes = <String>{
  'List',
  'Iterable',
  'Set',
  'Stream',
  'Queue',
};

/// The one library a consumer imports. Everything checked here is derived from
/// its `export` directives, not from a list kept by hand.
///
/// That matters: a hand-kept list drifts, and drift in *this* test is silent
/// permission. `src/ffi/**` is never named below and is never reached, which
/// is the point -- it is the native plumbing, it is not exported, and pointers
/// live there legitimately. If anything from it ever surfaced, the walk would
/// arrive at `Pointer` or `RkInferLib` and fail.
const String contractLibrary = 'package:rk_infer/rk_infer.dart';

/// One thing that is wrong, said in a way that names the culprit.
class Violation {
  Violation(this.where, this.what, this.why);
  final String where;
  final String what;
  final String why;

  @override
  String toString() => '$where returns $what -- $why';
}

void main() {
  group('the contract cannot hand a frame back', () {
    late List<DeclarationMirror> surface;

    setUp(() {
      final lib = currentMirrorSystem().libraries[Uri.parse(contractLibrary)];
      expect(
        lib,
        isNotNull,
        reason:
            '$contractLibrary is not loaded, so this test would check '
            'nothing. That is worse than a failure: fix the import, do not '
            'relax the test.',
      );
      surface = _exportedSurface(lib!);
    });

    test('the walk actually reaches the surface it claims to check', () {
      // A structural test that silently walks nothing passes forever. Pin the
      // shape of what it visits so an empty walk is a failure, not a green.
      final names = surface.map((d) => MirrorSystem.getName(d.simpleName));
      for (final expected in <String>[
        'InferenceEngine',
        'NativeInferenceEngine',
        'InferenceOutput',
        'Detection',
        'LoadedModel',
        'EngineCapabilities',
        'InferResult',
        'InferError',
        'FrameSpec',
        'ModelRef',
        'hasNativeEngine',
      ]) {
        expect(
          names,
          contains(expected),
          reason:
              'the export surface does not include $expected, so this test '
              'proves nothing about it',
        );
      }

      final visited = _walk(surface).visited;
      expect(
        visited.length,
        greaterThanOrEqualTo(20),
        reason:
            'only ${visited.length} types were reached; the public surface '
            'is larger than that, so the walk is not doing its job',
      );
      expect(
        visited,
        containsAll(<String>['InferenceOutput', 'Detection', 'LoadedModel']),
        reason:
            'the walk must descend into the types a run hands back, not '
            'stop at the interface',
      );
    });

    test('no exported declaration returns anything byte-shaped', () {
      final result = _walk(surface);

      expect(
        result.violations,
        isEmpty,
        reason:
            'Section 21 is enforced by construction here, not by a rule '
            'anyone has to remember. Each line below is a way a raw frame '
            'could leave the worker that owns it:\n'
            '${result.violations.map((v) => '  - $v').join('\n')}',
      );
    });

    test('the exported surface exposes no I/O of its own', () {
      // "Writes one to disk, opens a socket" is not only about return types:
      // a method named `save`, `write`, `connect` or `dump` here would be the
      // wrong shape whatever it returned. The frame comes from a video source
      // that is somebody else's component, and the result goes to a journal
      // that is somebody else's component.
      const forbiddenVerbs = <String>[
        'save',
        'write',
        'dump',
        'export',
        'connect',
        'listen',
        'bind',
        'upload',
        'snapshot',
        'capture',
        'toBytes',
        'asBytes',
      ];

      final offenders = <String>[];
      for (final decl in surface) {
        if (decl is! ClassMirror || decl.isPrivate) continue;
        final owner = MirrorSystem.getName(decl.simpleName);
        for (final member in decl.declarations.values) {
          if (member is! MethodMirror || member.isPrivate) continue;
          final raw = MirrorSystem.getName(member.simpleName);
          final name = raw.toLowerCase();
          for (final verb in forbiddenVerbs) {
            if (name.startsWith(verb.toLowerCase())) {
              offenders.add('$owner.$raw');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these look like a way out of the process: '
            '${offenders.join(", ")}',
      );
    });
  });
}

/// Exactly what `package:rk_infer/rk_infer.dart` gives a consumer: its own
/// public top-level declarations, plus the names each `export` shows.
///
/// Derived from the export directives rather than listed by hand, because a
/// hand-kept list drifts and drift here is silent permission.
List<DeclarationMirror> _exportedSurface(LibraryMirror root) {
  final out = <DeclarationMirror>[];

  for (final decl in root.declarations.values) {
    if (!decl.isPrivate) out.add(decl);
  }

  for (final dep in root.libraryDependencies) {
    if (!dep.isExport) continue;
    final target = dep.targetLibrary;
    if (target == null) continue;

    final shown = <Symbol>{};
    final hidden = <Symbol>{};
    for (final combinator in dep.combinators) {
      if (combinator.isShow) {
        shown.addAll(combinator.identifiers);
      } else {
        hidden.addAll(combinator.identifiers);
      }
    }

    for (final entry in target.declarations.entries) {
      if (entry.value.isPrivate) continue;
      if (shown.isNotEmpty && !shown.contains(entry.key)) continue;
      if (hidden.contains(entry.key)) continue;
      out.add(entry.value);
    }
  }

  return out;
}

class _WalkResult {
  _WalkResult(this.violations, this.visited);
  final List<Violation> violations;
  final Set<String> visited;
}

/// Walks every declaration on the exported surface and everything reachable
/// from their types.
_WalkResult _walk(List<DeclarationMirror> surface) {
  final violations = <Violation>[];
  final visited = <String>{};
  final queue = <ClassMirror>[];

  void checkType(String where, TypeMirror type) {
    final name = MirrorSystem.getName(type.simpleName);

    if (byteBearingTypes.contains(name)) {
      violations.add(
        Violation(
          where,
          name,
          'that is a frame, or something that can hold one',
        ),
      );
      return;
    }

    if (opaqueEscapeHatches.contains(name)) {
      violations.add(
        Violation(
          where,
          name,
          'this can hold anything, so this test could no longer tell whether '
          'it holds a frame. Name a real type.',
        ),
      );
      return;
    }

    final args = type.typeArguments;

    if (collectionTypes.contains(name) &&
        args.length == 1 &&
        byteElementTypes.contains(
          MirrorSystem.getName(args.first.simpleName),
        )) {
      violations.add(
        Violation(
          where,
          '$name<${MirrorSystem.getName(args.first.simpleName)}>',
          'a sequence of ints is a frame written the long way',
        ),
      );
      return;
    }

    for (final arg in args) {
      checkType('$where (type argument of $name)', arg);
    }

    if (type is ClassMirror &&
        !type.isPrivate &&
        !visited.contains(name) &&
        // Type variables and the SDK's own types are not ours to police.
        !_isSdkType(type)) {
      queue.add(type);
    }
  }

  void enqueueClass(ClassMirror cls) {
    final name = MirrorSystem.getName(cls.simpleName);
    if (!visited.add(name)) return;

    for (final member in cls.declarations.values) {
      if (member.isPrivate) continue;
      final memberName = MirrorSystem.getName(member.simpleName);
      final where = '$name.$memberName';

      if (member is MethodMirror) {
        // Constructors return the class itself; setters return void. Neither
        // is a way out.
        if (member.isConstructor || member.isSetter) continue;
        checkType(where, member.returnType);
      } else if (member is VariableMirror) {
        checkType(where, member.type);
      }
    }
  }

  for (final decl in surface) {
    if (decl.isPrivate) continue;
    final name = MirrorSystem.getName(decl.simpleName);

    if (decl is ClassMirror) {
      queue.add(decl);
    } else if (decl is MethodMirror) {
      if (decl.isSetter) continue;
      checkType('(top level) $name', decl.returnType);
    } else if (decl is VariableMirror) {
      checkType('(top level) $name', decl.type);
    }
  }

  while (queue.isNotEmpty) {
    enqueueClass(queue.removeLast());
  }

  return _WalkResult(violations, visited);
}

bool _isSdkType(ClassMirror cls) {
  final uri = cls.owner is LibraryMirror
      ? (cls.owner! as LibraryMirror).uri.toString()
      : '';
  return uri.startsWith('dart:');
}
