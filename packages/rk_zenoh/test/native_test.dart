/// The binding against a real native library.
///
/// Skipped when the library has not been built. Build it with
/// `cargo build --release` inside `rust/`, or point `RK_ZENOH_LIBRARY` at a
/// copy. **These tests are not skipped in the ordinary sense of "optional"**:
/// a binding that has never loaded its library has been proved by nothing, so
/// the reason it was skipped is printed rather than swallowed.
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:rk_zenoh/rk_zenoh.dart';
import 'package:test/test.dart';

String? locateLibrary() {
  final fromEnvironment = Platform.environment['RK_ZENOH_LIBRARY'];
  if (fromEnvironment != null && File(fromEnvironment).existsSync()) {
    return fromEnvironment;
  }
  final name = defaultLibraryFileName();
  final s = Platform.pathSeparator;
  for (final root in ['rust${s}target']) {
    for (final profile in ['release', 'debug']) {
      final path = '$root$s$profile$s$name';
      if (File(path).existsSync()) return File(path).absolute.path;
    }
  }
  return null;
}

Future<int> freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  final libraryPath = locateLibrary();
  if (libraryPath == null) {
    test('the native library is missing', () {
      // ignore: avoid_print
      print(
        'rk_zenoh: no native library found; run `cargo build --release` '
        'in rust/, or set RK_ZENOH_LIBRARY.',
      );
    }, skip: 'native library not built');
    return;
  }

  Future<ZenohSession> openServer(int port) => ZenohSession.open(
    ZenohConfig(listen: ['tcp/127.0.0.1:$port']),
    libraryPath: libraryPath,
  );

  Future<ZenohSession> openTill(int port) => ZenohSession.open(
    ZenohConfig(connect: ['tcp/127.0.0.1:$port']),
    libraryPath: libraryPath,
  );

  test('a missing library is reported with everywhere it looked', () {
    expect(
      () => ZenohSession.open(
        ZenohConfig(),
        libraryPath: 'no-such-library-anywhere',
      ),
      throwsA(
        isA<RkzLibraryNotFound>().having(
          (e) => e.toString(),
          'message',
          contains('no-such-library-anywhere'),
        ),
      ),
    );
  });

  test('a pinned identity without tls never reaches the native side', () {
    expect(
      () => ZenohSession.open(
        ZenohConfig(
          identity: const ZenohIdentity.derivedFrom('till-17'),
          connect: ['tcp/127.0.0.1:7447'],
        ),
        libraryPath: libraryPath,
      ),
      throwsA(
        isA<RkzException>().having(
          (e) => e.kind,
          'kind',
          RkzErrorKind.invalidConfig,
        ),
      ),
    );
  });

  test(
    'a session opens, reports a zid, and closes twice without complaint',
    () async {
      final port = await freePort();
      final session = await openServer(port);
      addTearDown(session.close);

      expect(session.zid, matches(RegExp(r'^[0-9a-f]+$')));
      expect(session.zid.length, lessThanOrEqualTo(32));
      expect(await session.peerZids(), isEmpty);

      await session.close();
      await session.close();
    },
  );

  test('a message published on one session arrives on the other', () async {
    final port = await freePort();
    final server = await openServer(port);
    addTearDown(server.close);
    final till = await openTill(port);
    addTearDown(till.close);

    expect(till.zid, isNot(server.zid));

    final sub = await till.subscribe('telepos/till/till-17/cmd');
    final received = <ZenohSample>[];
    final listening = sub.samples.listen(received.add);
    addTearDown(listening.cancel);

    // Retry: a subscription takes a moment to propagate, and a put with
    // nothing matching yet succeeds and delivers nothing.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (received.isEmpty && DateTime.now().isBefore(deadline)) {
      await server.put('telepos/till/till-17/cmd', utf8.encode('open-drawer'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(received, isNotEmpty, reason: 'the message never arrived');
    expect(received.first.key, 'telepos/till/till-17/cmd');
    expect(received.first.kind, SampleKind.put);
    expect(received.first.text, 'open-drawer');
    await sub.close();
  });

  test(
    'a liveliness token appears as a put and vanishes as a delete',
    () async {
      final port = await freePort();
      final server = await openServer(port);
      addTearDown(server.close);

      final watcher = await server.watchLiveliness('telepos/alive/**');
      final events = <ZenohSample>[];
      final done = watcher.samples.listen(events.add);
      addTearDown(done.cancel);

      final till = await openTill(port);
      addTearDown(till.close);
      final token = await till.declareLiveliness('telepos/alive/till-17');

      await _until(
        () => events.any((e) => e.kind == SampleKind.put),
        'the token must be announced',
      );
      expect(events.first.key, 'telepos/alive/till-17');

      await token.close();
      await _until(
        () => events.any((e) => e.kind == SampleKind.delete),
        'the token going away must be announced',
      );
      await watcher.close();
    },
  );

  test('a malformed key expression fails as a value, not as a crash', () async {
    final port = await freePort();
    final session = await openServer(port);
    addTearDown(session.close);

    await expectLater(
      session.subscribe('a/**b'),
      throwsA(
        isA<RkzException>().having(
          (e) => e.kind,
          'kind',
          RkzErrorKind.invalidKeyExpression,
        ),
      ),
    );

    // The session is still usable: the failure was returned, not thrown out
    // of the native stack (И144).
    expect(await session.peerZids(), isEmpty);
  });

  test('using a closed session is refused rather than undefined', () async {
    final port = await freePort();
    final session = await openServer(port);
    await session.close();
    expect(
      () => session.peerZids(),
      throwsA(
        isA<RkzException>().having(
          (e) => e.kind,
          'kind',
          RkzErrorKind.sessionClosed,
        ),
      ),
    );
  });

  /// **The stale ZID, from Dart.**
  ///
  /// The Rust side measures the fabric; this measures what a Dart caller sees.
  /// A restarted session has a different [ZenohSession.zid], so anything that
  /// stored the old one is addressing nothing — and the put that goes nowhere
  /// still succeeds.
  test(
    'a recreated session gets a different zid and the old one goes nowhere',
    () async {
      final port = await freePort();
      final server = await openServer(port);
      addTearDown(server.close);

      var till = await openTill(port);
      final oldZid = till.zid;
      await till.close();

      till = await openTill(port);
      addTearDown(till.close);
      expect(
        till.zid,
        isNot(oldZid),
        reason: 'an unpinned session must come back as someone else',
      );

      final sub = await till.subscribe('telepos/direct/${till.zid}/cmd');
      final toTheDead = <ZenohSample>[];
      final listening = sub.samples.listen(toTheDead.add);
      addTearDown(listening.cancel);

      // Address the till the way a naive cache would: by the zid it used to have.
      for (var i = 0; i < 20; i++) {
        await server.put(
          'telepos/direct/$oldZid/cmd',
          utf8.encode('open-drawer'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        toTheDead,
        isEmpty,
        reason: 'every one of those puts succeeded and delivered nothing',
      );
      await sub.close();
    },
  );
}

Future<void> _until(bool Function() predicate, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('$what did not happen in time');
}
