import 'package:rk_pki/rk_pki.dart';
import 'package:test/test.dart';

void main() {
  group('the envelope', () {
    test('reads a value out of a success', () {
      final result = decodeEnvelope('{"ok":true,"value":{"a":1}}');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, <String, Object?>{'a': 1});
    });

    test('reads a failure by name', () {
      final result = decodeEnvelope(
        '{"ok":false,"error":{"kind":"inviteInvalid"}}',
      );
      expect(result.errorOrNull, isA<InviteInvalid>());
    });

    test('text that is not JSON is a failure, not an exception', () {
      final result = decodeEnvelope('<html>gateway timeout</html>');
      expect(result.errorOrNull, isA<NativeFault>());
    });

    test('an envelope without ok is refused rather than guessed at', () {
      for (final text in <String>[
        '{"value":{}}',
        '{"ok":"yes","value":{}}',
        '[1,2,3]',
        '{"ok":true}',
        '{"ok":false}',
      ]) {
        final result = decodeEnvelope(text);
        expect(result.isOk, isFalse, reason: text);
        expect(result.errorOrNull, isA<NativeFault>(), reason: text);
      }
    });

    test('a value of an unexpected shape is a failure, not a crash', () {
      final result = decodeEnvelopeAs<String>(
        '{"ok":true,"value":{"certPem":42}}',
        (Map<String, Object?> value) => value['certPem']! as String,
      );
      expect(result.errorOrNull, isA<NativeFault>());
    });

    test('a failure survives being reshaped', () {
      final result = decodeEnvelopeAs<String>(
        '{"ok":false,"error":{"kind":"caUnreachable","detail":"no route"}}',
        (Map<String, Object?> value) => value['nothing']! as String,
      );
      expect(result.errorOrNull, isA<CaUnreachable>());
      expect(result.errorOrNull!.detail, 'no route');
    });
  });
}
