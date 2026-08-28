/// Names cross the boundary; numbers do not (I147).
library;

import 'package:rk_nats/rk_nats.dart';
import 'package:test/test.dart';

void main() {
  group('codes', () {
    test('are read by name', () {
      expect(rkNatsCodeFromName('ok'), RkNatsCode.ok);
      expect(
        rkNatsCodeFromName('durabilityUnproven'),
        RkNatsCode.durabilityUnproven,
      );
      expect(rkNatsCodeFromName('panic'), RkNatsCode.panic);
    });

    test('are never read by position', () {
      // If codes crossed as indices, `0` would arrive here and become
      // whichever case happens to be first in this build. It does not.
      expect(rkNatsCodeFromName(0), RkNatsCode.unrecognised);
      expect(rkNatsCodeFromName(5), RkNatsCode.unrecognised);
      expect(rkNatsCodeFromName('0'), RkNatsCode.unrecognised);
    });

    test('an unfamiliar name is unrecognised, never ok', () {
      // A native library newer than this binding will one day send a name from
      // the future. Mapping it to `ok` would report a success nobody had.
      expect(
        rkNatsCodeFromName('somethingFromTheFuture'),
        RkNatsCode.unrecognised,
      );
      expect(rkNatsCodeFromName(null), RkNatsCode.unrecognised);
      expect(rkNatsCodeFromName(''), RkNatsCode.unrecognised);
    });

    test('the known list excludes the catch-all', () {
      expect(rkNatsKnownCodeNames, isNot(contains('unrecognised')));
      expect(rkNatsKnownCodeNames, contains('durabilityWeakerThanRequested'));
    });
  });

  group('ack meanings', () {
    test(
      'are read by name and default to unknown, never to something calm',
      () {
        expect(
          rkNatsAckMeaningFromName('fsyncedToDisk'),
          RkNatsAckMeaning.fsyncedToDisk,
        );
        expect(rkNatsAckMeaningFromName(1), RkNatsAckMeaning.unknown);
        expect(
          rkNatsAckMeaningFromName('probablyOnDisk'),
          RkNatsAckMeaning.unknown,
        );
      },
    );
  });

  group('persistence mode', () {
    test('translates the one name that cannot be spelled in Dart', () {
      // `default` is a Dart keyword, so this is the single place where the two
      // sides use different spellings, and it is a named function with a test
      // rather than a literal somewhere in a request builder.
      expect(
        rkNatsPersistModeWireName(RkNatsPersistMode.serverDefault),
        'default',
      );
      expect(rkNatsPersistModeWireName(RkNatsPersistMode.async), 'async');
      expect(
        rkNatsPersistModeFromWireName('default'),
        RkNatsPersistMode.serverDefault,
      );
      expect(rkNatsPersistModeFromWireName('async'), RkNatsPersistMode.async);
      expect(rkNatsPersistModeFromWireName('serverDefault'), isNull);
      expect(rkNatsPersistModeFromWireName(0), isNull);
    });
  });

  group('policies', () {
    test('go on the wire as their Dart names, so the mirror stays honest', () {
      expect(RkNatsDurability.fsyncOnAck.name, 'fsyncOnAck');
      expect(RkNatsDurability.flushOnAck.name, 'flushOnAck');
      expect(RkNatsDurability.ackIsMemoryOnly.name, 'ackIsMemoryOnly');
    });
  });
}
