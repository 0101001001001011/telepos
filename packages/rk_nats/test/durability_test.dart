/// The durability contract, which is the reason this package exists.
///
/// Nothing here needs a server or the native library. That is deliberate: a
/// rule about what an acknowledgement means has to be checkable by anyone who
/// checks out the package, or it will be checked by nobody.
library;

import 'package:rk_nats/rk_nats.dart';
import 'package:test/test.dart';

/// Facts as a live nats-server reported them. Captured on 2026-07-31 from
/// `http://127.0.0.1:18222/varz` and its two siblings; the full documents are
/// in `rust/fixtures/`.
const twoMinutes = Duration(minutes: 2);

RkNatsServerDurability defaultServer() => const RkNatsServerDurability(
  version: '2.14.4',
  syncAlways: false,
  syncInterval: twoMinutes,
  storeDir: '/var/lib/nats',
);

RkNatsServerDurability fsyncAlwaysServer() => const RkNatsServerDurability(
  version: '2.14.4',
  syncAlways: true,
  // Measured, and the trap: turning fsync-on-write on leaves this at two
  // minutes. A check that read this field alone would call this server
  // unsafe, and would be wrong.
  syncInterval: twoMinutes,
  storeDir: '/var/lib/nats',
);

void main() {
  group('the default', () {
    test('is the safe policy, without the caller naming anything', () {
      const options = RkNatsConnectOptions(servers: ['nats://till:4222']);
      expect(options.durability, RkNatsDurability.fsyncOnAck);
      expect(options.toJson()['policy'], 'fsyncOnAck');
    });

    test('is refused rather than downgraded when nothing proves it', () {
      // No evidence configured, so the ack means nothing known, so the publish
      // does not happen. The whole design in one assertion.
      expect(
        rkNatsGate(
          policy: RkNatsDurability.fsyncOnAck,
          meaning: RkNatsAckMeaning.unknown,
          acceptedFsyncLag: Duration.zero,
        ),
        RkNatsCode.durabilityUnproven,
      );
    });

    test('is a file-backed stream in the server default persistence mode', () {
      const options = RkNatsStreamOptions(name: 'sales');
      expect(options.storage, RkNatsStorage.file);
      expect(options.persistMode, RkNatsPersistMode.serverDefault);
      expect(options.toJson(1)['storage'], 'file');
      expect(options.toJson(1)['persistMode'], 'default');
    });
  });

  group('what an ack means', () {
    test('is unknown without evidence, never a hopeful guess', () {
      expect(
        rkNatsAckMeaning(
          server: null,
          storage: RkNatsStorage.file,
          persistMode: RkNatsPersistMode.serverDefault,
        ),
        RkNatsAckMeaning.unknown,
      );
    });

    test('on a default server, is written but not fsynced', () {
      expect(
        rkNatsAckMeaning(
          server: defaultServer(),
          storage: RkNatsStorage.file,
          persistMode: RkNatsPersistMode.serverDefault,
        ),
        RkNatsAckMeaning.writtenNotFsynced,
      );
    });

    test('on a fsync-always server, is fsynced to disk', () {
      expect(
        rkNatsAckMeaning(
          server: fsyncAlwaysServer(),
          storage: RkNatsStorage.file,
          persistMode: RkNatsPersistMode.serverDefault,
        ),
        RkNatsAckMeaning.fsyncedToDisk,
      );
    });

    test('is defeated by async persistence even on a fsync-always server', () {
      // The measured trap. Same server, same disk, ack before the store.
      // 4 198 msg/s in async mode against 158 msg/s in default mode: it is not
      // waiting for anything, and its ack looks identical to one that is.
      expect(
        rkNatsAckMeaning(
          server: fsyncAlwaysServer(),
          storage: RkNatsStorage.file,
          persistMode: RkNatsPersistMode.async,
        ),
        RkNatsAckMeaning.ackedBeforeStore,
      );
    });

    test('is memory-only when the stream is, whatever the server does', () {
      expect(
        rkNatsAckMeaning(
          server: fsyncAlwaysServer(),
          storage: RkNatsStorage.memory,
          persistMode: RkNatsPersistMode.serverDefault,
        ),
        RkNatsAckMeaning.memoryOnly,
      );
    });
  });

  group('fsyncOnAck', () {
    test('admits a fsynced ack and nothing else', () {
      for (final meaning in RkNatsAckMeaning.values) {
        final verdict = rkNatsGate(
          policy: RkNatsDurability.fsyncOnAck,
          meaning: meaning,
          acceptedFsyncLag: Duration.zero,
          server: fsyncAlwaysServer(),
        );
        if (meaning == RkNatsAckMeaning.fsyncedToDisk) {
          expect(verdict, isNull, reason: '$meaning must pass');
        } else {
          expect(
            verdict,
            isNotNull,
            reason: '$meaning must not pass as fsynced',
          );
        }
      }
    });

    test('says "not proven" and "proven weaker" with different words', () {
      // They need different words because they need different fixes: one is
      // "go and ask the server", the other is "your server is unsafe".
      expect(
        rkNatsGate(
          policy: RkNatsDurability.fsyncOnAck,
          meaning: RkNatsAckMeaning.unknown,
          acceptedFsyncLag: Duration.zero,
        ),
        RkNatsCode.durabilityUnproven,
      );
      expect(
        rkNatsGate(
          policy: RkNatsDurability.fsyncOnAck,
          meaning: RkNatsAckMeaning.writtenNotFsynced,
          acceptedFsyncLag: Duration.zero,
          server: defaultServer(),
        ),
        RkNatsCode.durabilityWeakerThanRequested,
      );
    });

    test('refuses an ack that precedes the store', () {
      expect(
        rkNatsGate(
          policy: RkNatsDurability.fsyncOnAck,
          meaning: RkNatsAckMeaning.ackedBeforeStore,
          acceptedFsyncLag: Duration.zero,
          server: fsyncAlwaysServer(),
        ),
        RkNatsCode.durabilityWeakerThanRequested,
      );
    });
  });

  group('flushOnAck', () {
    test('cannot be chosen without naming a window', () {
      const options = RkNatsConnectOptions(
        servers: ['nats://till:4222'],
        durability: RkNatsDurability.flushOnAck,
      );
      expect(options.problem, RkNatsCode.invalidRequest);
    });

    test('is fine once a window is named', () {
      const options = RkNatsConnectOptions(
        servers: ['nats://till:4222'],
        durability: RkNatsDurability.flushOnAck,
        acceptedFsyncLag: Duration(minutes: 5),
      );
      expect(options.problem, isNull);
      expect(options.toJson()['acceptedFsyncLagNanos'], 300000000000);
    });

    test('checks the named window against the server own', () {
      expect(
        rkNatsGate(
          policy: RkNatsDurability.flushOnAck,
          meaning: RkNatsAckMeaning.writtenNotFsynced,
          acceptedFsyncLag: const Duration(minutes: 5),
          server: defaultServer(),
        ),
        isNull,
      );
      expect(
        rkNatsGate(
          policy: RkNatsDurability.flushOnAck,
          meaning: RkNatsAckMeaning.writtenNotFsynced,
          acceptedFsyncLag: const Duration(seconds: 1),
          server: defaultServer(),
        ),
        RkNatsCode.fsyncLagTooLong,
      );
    });

    test('treats an unknown window as too long, not as short enough', () {
      expect(
        rkNatsGate(
          policy: RkNatsDurability.flushOnAck,
          meaning: RkNatsAckMeaning.writtenNotFsynced,
          acceptedFsyncLag: const Duration(days: 365),
        ),
        RkNatsCode.fsyncLagTooLong,
      );
    });

    test('still refuses an ack that precedes the store', () {
      for (final meaning in [
        RkNatsAckMeaning.ackedBeforeStore,
        RkNatsAckMeaning.memoryOnly,
      ]) {
        expect(
          rkNatsGate(
            policy: RkNatsDurability.flushOnAck,
            meaning: meaning,
            acceptedFsyncLag: const Duration(days: 365),
            server: fsyncAlwaysServer(),
          ),
          RkNatsCode.durabilityWeakerThanRequested,
          reason: '$meaning',
        );
      }
    });
  });

  group('ackIsMemoryOnly', () {
    test('admits everything, because it promised nothing', () {
      for (final meaning in RkNatsAckMeaning.values) {
        expect(
          rkNatsGate(
            policy: RkNatsDurability.ackIsMemoryOnly,
            meaning: meaning,
            acceptedFsyncLag: Duration.zero,
          ),
          isNull,
          reason: '$meaning',
        );
      }
    });

    test('needs no window named, because it accepts losing everything', () {
      const options = RkNatsConnectOptions(
        servers: ['nats://till:4222'],
        durability: RkNatsDurability.ackIsMemoryOnly,
      );
      expect(options.problem, isNull);
    });
  });

  group('reading the server back', () {
    test('takes syncAlways and syncInterval as the library sends them', () {
      final server = RkNatsServerDurability.fromJson(const {
        'version': '2.14.4',
        'syncAlways': true,
        'syncIntervalNanos': 120000000000,
        'storeDir': r'jsstore2\jetstream',
      });
      expect(server.syncAlways, isTrue);
      expect(server.syncInterval, twoMinutes);
      expect(server.storeDir, r'jsstore2\jetstream');
    });

    test('a missing syncAlways is false, not unknown', () {
      // The server omits the field when it is false, which is its own encoding.
      // Reading absence as "unknown" would refuse every server that is merely
      // unsafe-by-default, which is all of them, and nobody would learn
      // anything from a refusal that never distinguishes.
      final server = RkNatsServerDurability.fromJson(const {
        'version': '2.11.0',
        'syncIntervalNanos': 120000000000,
      });
      expect(server.syncAlways, isFalse);
      expect(
        rkNatsAckMeaning(
          server: server,
          storage: RkNatsStorage.file,
          persistMode: RkNatsPersistMode.serverDefault,
        ),
        RkNatsAckMeaning.writtenNotFsynced,
      );
    });
  });
}
