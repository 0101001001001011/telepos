/// End to end through the public Dart surface, against real nats-servers.
///
/// Tagged `live` and excluded by default in `dart_test.yaml`, because a suite
/// that goes green without a server would be reporting that durability was
/// checked when nothing was checked. Run it deliberately:
///
/// ```text
/// nats-server -js -sd ./a -p 14222 -m 18222
/// nats-server -c sync_always.conf                    # 14223, http 18223
/// dart test --tags live
/// ```
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:rk_nats/rk_nats.dart';
import 'package:test/test.dart';

import 'support/library.dart';

String env(String name, String fallback) =>
    Platform.environment[name] ?? fallback;

/// The monitoring document, fetched the way a caller would fetch it.
Future<String> varz(String hostPort) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('http://$hostPort/varz'));
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

String unique(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

void main() {
  final path = findNativeLibrary();
  if (path == null) {
    test('live', () {}, skip: buildTheLibraryFirst);
    return;
  }

  final unsafeServer = env('RK_NATS_LIVE_DEFAULT', '127.0.0.1:14222');
  final unsafeHttp = env('RK_NATS_LIVE_DEFAULT_HTTP', '127.0.0.1:18222');
  final safeServer = env('RK_NATS_LIVE_SYNC_ALWAYS', '127.0.0.1:14223');
  final safeHttp = env('RK_NATS_LIVE_SYNC_ALWAYS_HTTP', '127.0.0.1:18223');

  test('a default server cannot satisfy the default policy', () async {
    final result = await RkNatsClient.connect(
      RkNatsConnectOptions(
        servers: ['nats://$unsafeServer'],
        name: 'till-17',
        evidence: RkNatsVarzEvidence(await varz(unsafeHttp)),
      ),
      libraryPath: path,
    );
    expect(result.isOk, isTrue, reason: result.message);
    final client = result.value!;
    addTearDown(client.close);

    expect(client.ackMeaning, RkNatsAckMeaning.writtenNotFsynced);
    expect(client.satisfiesPolicy, isFalse);

    final stream = await client.ensureStream(
      RkNatsStreamOptions(name: unique('rk_dart_refused')),
    );
    expect(stream.isOk, isFalse);
    expect(stream.code, RkNatsCode.streamRefusedWeakerThanPolicy);
  });

  test(
    'without evidence the default policy refuses before it writes',
    () async {
      final result = await RkNatsClient.connect(
        RkNatsConnectOptions(servers: ['nats://$unsafeServer']),
        libraryPath: path,
      );
      expect(result.isOk, isTrue, reason: result.message);
      final client = result.value!;
      addTearDown(client.close);

      expect(client.durability.code, RkNatsCode.durabilityUnproven);
      expect(client.ackMeaning, RkNatsAckMeaning.unknown);

      final stream = await client.ensureStream(
        RkNatsStreamOptions(name: unique('rk_dart_unproven')),
      );
      expect(stream.code, RkNatsCode.durabilityUnproven);
    },
  );

  test(
    'a fsync-always server carries a sale and says what the ack meant',
    () async {
      final result = await RkNatsClient.connect(
        RkNatsConnectOptions(
          servers: ['nats://$safeServer'],
          name: 'till-17',
          evidence: RkNatsVarzEvidence(await varz(safeHttp)),
        ),
        libraryPath: path,
      );
      expect(result.isOk, isTrue, reason: result.message);
      final client = result.value!;
      addTearDown(client.close);

      expect(client.ackMeaning, RkNatsAckMeaning.fsyncedToDisk);
      expect(client.satisfiesPolicy, isTrue);

      final name = unique('rk_dart_sales');
      final stream = await client.ensureStream(
        RkNatsStreamOptions(name: name, subjects: ['$name.>']),
      );
      expect(stream.isOk, isTrue, reason: stream.message);
      expect(stream.value!.ackMeaning, RkNatsAckMeaning.fsyncedToDisk);
      expect(stream.value!.persistModeHonoured, isTrue);

      final ack = await client.publish(
        stream: name,
        subject: '$name.till17',
        payload: utf8.encode('{"total":"123.450"}'),
        messageId: 'receipt-000017-1',
      );
      expect(ack.isOk, isTrue, reason: ack.message);
      expect(ack.value!.ackMeaning, RkNatsAckMeaning.fsyncedToDisk);
      expect(ack.value!.duplicate, isFalse);

      // A retry of the same receipt is the same receipt.
      final retry = await client.publish(
        stream: name,
        subject: '$name.till17',
        payload: utf8.encode('{"total":"123.450"}'),
        messageId: 'receipt-000017-1',
      );
      expect(retry.isOk, isTrue, reason: retry.message);
      expect(retry.value!.duplicate, isTrue);
      expect(retry.value!.sequence, ack.value!.sequence);

      // And the shop server picks it up exactly once.
      final batch = await client.fetch(stream: name, consumer: 'shop-server');
      expect(batch.isOk, isTrue, reason: batch.message);
      expect(batch.value, hasLength(1));
      expect(utf8.decode(batch.value!.single.payload), '{"total":"123.450"}');

      final acked = await client.ack(batch.value!.single);
      expect(acked.isOk, isTrue, reason: acked.message);

      final again = await client.fetch(stream: name, consumer: 'shop-server');
      expect(again.value, isEmpty, reason: 'an acknowledged message came back');
    },
  );

  test('async persistence is refused even on a fsync-always server', () async {
    final result = await RkNatsClient.connect(
      RkNatsConnectOptions(
        servers: ['nats://$safeServer'],
        evidence: RkNatsVarzEvidence(await varz(safeHttp)),
      ),
      libraryPath: path,
    );
    final client = result.value!;
    addTearDown(client.close);

    final stream = await client.ensureStream(
      RkNatsStreamOptions(
        name: unique('rk_dart_async'),
        persistMode: RkNatsPersistMode.async,
      ),
    );
    expect(stream.code, RkNatsCode.streamRefusedWeakerThanPolicy);
    expect(stream.message, contains('ackedBeforeStore'));
  });

  test('the fast path is available to anyone who names it', () async {
    final result = await RkNatsClient.connect(
      RkNatsConnectOptions(
        servers: ['nats://$safeServer'],
        durability: RkNatsDurability.ackIsMemoryOnly,
        evidence: RkNatsVarzEvidence(await varz(safeHttp)),
      ),
      libraryPath: path,
    );
    final client = result.value!;
    addTearDown(client.close);

    final name = unique('rk_dart_telemetry');
    final stream = await client.ensureStream(
      RkNatsStreamOptions(
        name: name,
        subjects: ['$name.>'],
        persistMode: RkNatsPersistMode.async,
      ),
    );
    expect(stream.isOk, isTrue, reason: stream.message);
    expect(stream.value!.effectivePersistMode, RkNatsPersistMode.async);

    final ack = await client.publish(
      stream: name,
      subject: '$name.cpu',
      payload: utf8.encode('42'),
    );
    expect(ack.isOk, isTrue, reason: ack.message);
    expect(
      ack.value!.ackMeaning,
      RkNatsAckMeaning.ackedBeforeStore,
      reason: 'the ack must keep saying what it means, on every message',
    );
  });

  test('a named window shorter than the server own is refused', () async {
    final result = await RkNatsClient.connect(
      RkNatsConnectOptions(
        servers: ['nats://$unsafeServer'],
        durability: RkNatsDurability.flushOnAck,
        acceptedFsyncLag: const Duration(seconds: 1),
        evidence: RkNatsVarzEvidence(await varz(unsafeHttp)),
      ),
      libraryPath: path,
    );
    final client = result.value!;
    addTearDown(client.close);

    final stream = await client.ensureStream(
      RkNatsStreamOptions(name: unique('rk_dart_lag')),
    );
    expect(stream.code, RkNatsCode.fsyncLagTooLong);
  });

  test('a publish never runs on the isolate that called it (I145)', () async {
    // Evidence rather than assertion: while a publish is in flight, this
    // isolate keeps running. If the call were made here, the microtask below
    // could not be serviced until it returned.
    final result = await RkNatsClient.connect(
      RkNatsConnectOptions(
        servers: ['nats://$safeServer'],
        evidence: RkNatsVarzEvidence(await varz(safeHttp)),
      ),
      libraryPath: path,
    );
    final client = result.value!;
    addTearDown(client.close);

    final name = unique('rk_dart_isolate');
    await client.ensureStream(
      RkNatsStreamOptions(name: name, subjects: ['$name.>']),
    );

    var ticks = 0;
    final ticker = Stream<void>.periodic(
      const Duration(milliseconds: 1),
    ).listen((_) => ticks++);
    addTearDown(ticker.cancel);

    for (var i = 0; i < 20; i++) {
      final ack = await client.publish(
        stream: name,
        subject: '$name.tick',
        payload: utf8.encode('$i'),
        messageId: 'tick-$i',
      );
      expect(ack.isOk, isTrue, reason: ack.message);
    }

    expect(
      ticks,
      greaterThan(0),
      reason:
          'this isolate was blocked for the whole run, so the native call '
          'was made on it',
    );
  });
}
