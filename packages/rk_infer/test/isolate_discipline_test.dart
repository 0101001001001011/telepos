/// И145 as a structural check.
///
/// "No call into the native side runs on the interface isolate" is enforced by
/// there being no synchronous way in: every method on the engine returns a
/// `Future` and is a message to a worker isolate. A synchronous method would
/// be the hole, so this fails if one appears.
///
/// # How to check that this test still bites
///
/// Add to `NativeInferenceEngine` in `lib/src/worker/engine_worker.dart`:
///
/// ```dart
/// int get abiVersionNow => _capabilities.abiVersion;
/// ```
///
/// `grep -n abiVersionNow lib/src/worker/engine_worker.dart` to confirm the
/// edit landed, then run this file. It must go red naming
/// `NativeInferenceEngine.abiVersionNow`. Done on 2026-07-31; see the report.
@TestOn('vm')
library;

import 'dart:mirrors';

import 'package:test/test.dart';

// ignore: unused_import
import 'package:rk_infer/rk_infer.dart';

/// Members that are allowed to be synchronous because they cannot reach the
/// native side: `Object`'s own, and the const/simple value types.
const Set<String> alwaysAllowed = <String>{
  'toString',
  'hashCode',
  '==',
  'runtimeType',
  'noSuchMethod',
};

void main() {
  group('nothing on the interface isolate', () {
    late ClassMirror engineInterface;
    late ClassMirror engineImplementation;

    setUp(() {
      final lib = currentMirrorSystem()
          .libraries[Uri.parse('package:rk_infer/rk_infer.dart')];
      expect(lib, isNotNull);

      ClassMirror find(String name) {
        for (final dep in lib!.libraryDependencies) {
          if (!dep.isExport) continue;
          for (final decl
              in dep.targetLibrary?.declarations.values ??
                  const <DeclarationMirror>[]) {
            if (decl is ClassMirror &&
                MirrorSystem.getName(decl.simpleName) == name) {
              return decl;
            }
          }
        }
        fail(
          '$name is not on the exported surface, so this test checks '
          'nothing about it',
        );
      }

      engineInterface = find('InferenceEngine');
      engineImplementation = find('NativeInferenceEngine');
    });

    test('every method on the engine interface returns a Future', () {
      final offenders = _synchronousMembers(engineInterface);
      expect(
        offenders,
        isEmpty,
        reason:
            'a synchronous method on this interface is the only shape of '
            'call that could run native code where the interface lives. '
            'Inference on the isolate that runs Flutter is a till frozen '
            'mid-sale. Offenders: ${offenders.join(", ")}',
      );
    });

    test('every method on the concrete engine returns a Future', () {
      final offenders = _synchronousMembers(engineImplementation);
      expect(
        offenders,
        isEmpty,
        reason:
            'the interface being async is worth nothing if the class a '
            'caller actually holds offers a synchronous shortcut. Offenders: '
            '${offenders.join(", ")}',
      );
    });

    test('the check reaches real members rather than an empty class', () {
      // A structural test over an empty set passes forever.
      final names = engineInterface.declarations.values
          .whereType<MethodMirror>()
          .where((m) => !m.isPrivate && !m.isConstructor)
          .map((m) => MirrorSystem.getName(m.simpleName))
          .toSet();

      expect(
        names,
        containsAll(<String>[
          'run',
          'loadModel',
          'unload',
          'close',
          'capabilities',
        ]),
        reason:
            'the interface does not declare the methods this test believes '
            'it is checking',
      );
    });

    test('the contract itself never touches dart:ffi', () {
      // И143's neighbour: the contract has to stay importable by anything that
      // is not the worker. A `dart:ffi` import here would tie the whole
      // package -- and everything that names its types -- to the VM's native
      // side.
      final contract = currentMirrorSystem()
          .libraries[Uri.parse('package:rk_infer/src/contract.dart')];
      expect(contract, isNotNull);

      final imported = contract!.libraryDependencies
          .where((d) => d.isImport)
          .map((d) => d.targetLibrary?.uri.toString())
          .whereType<String>()
          .toList();

      expect(
        imported,
        isNot(contains('dart:ffi')),
        reason: 'the contract imports dart:ffi; it imports $imported',
      );
      expect(
        imported.where((u) => u.startsWith('dart:')),
        <String>['dart:isolate'],
        reason:
            'the contract may take exactly one dart: import, '
            'dart:isolate for TransferableTypedData. Anything else is scope '
            'creeping into the layer that is supposed to be inert. Got: '
            '$imported',
      );
    });
  });
}

/// Public, non-constructor methods and getters whose return type is not a
/// `Future`.
List<String> _synchronousMembers(ClassMirror cls) {
  final owner = MirrorSystem.getName(cls.simpleName);
  final offenders = <String>[];

  for (final member in cls.declarations.values) {
    if (member is! MethodMirror) {
      // A public field is state, not a call, but a public *mutable* field on
      // the engine would be a way to reach in sideways. There are none, and
      // this keeps it that way.
      if (member is VariableMirror && !member.isPrivate && !member.isStatic) {
        offenders.add(
          '$owner.${MirrorSystem.getName(member.simpleName)} '
          '(a public field)',
        );
      }
      continue;
    }
    if (member.isPrivate || member.isConstructor || member.isSetter) continue;

    final name = MirrorSystem.getName(member.simpleName);
    if (alwaysAllowed.contains(name)) continue;

    // `start` is static and returns a Future too; a static that did not would
    // be just as bad, so it is not excused.
    final returns = MirrorSystem.getName(member.returnType.simpleName);
    if (returns != 'Future' && returns != 'Stream') {
      offenders.add('$owner.$name returns $returns');
    }
  }

  return offenders;
}
