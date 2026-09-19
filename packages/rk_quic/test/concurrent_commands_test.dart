@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';

import 'support/built_library.dart';

/// Every call answers with **its own** status, however many are in flight.
///
/// Found in a consumer, not here: a till serving a browser terminal writes to
/// many streams at once without awaiting one before the next. Before 0.2.2
/// each call took "the next reply to arrive" from a broadcast stream, so two
/// overlapping calls both received the first reply and the second reply went
/// to nobody. While every call succeeded the mix-up was invisible — `ok` handed
/// to the wrong caller is still `ok`. The moment one call failed (a write into a
/// stream the browser had just abandoned answers `peerGone`), the failure was
/// also handed to a healthy call running beside it, and that caller did the
/// right thing with a wrong fact: it closed a live subscription.
///
/// The check needs a started endpoint, and a started endpoint needs a
/// certificate. One is minted per run with `openssl` rather than checked in —
/// the same reason `rust/tests/session_lifecycle.rs` gives for minting its own.
void main() {
  late final String? libraryPath = locateBuiltLibrary();

  late Directory scratch;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('rk_quic_concurrent_');
  });

  tearDownAll(() async {
    await scratch.delete(recursive: true);
  });

  Future<QuicServer> startServer() async {
    final path = requireBuiltLibrary(libraryPath);
    final key = '${scratch.path}${Platform.pathSeparator}key.pem';
    final cert = '${scratch.path}${Platform.pathSeparator}cert.pem';
    final minted = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'ec',
      '-pkeyopt',
      'ec_paramgen_curve:prime256v1',
      '-nodes',
      '-keyout',
      key,
      '-out',
      cert,
      '-days',
      '10',
      '-subj',
      '/CN=localhost',
    ]);
    if (minted.exitCode != 0) {
      throw StateError(
        'openssl could not mint a test certificate, so this test would prove '
        'nothing by passing: ${minted.stderr}',
      );
    }
    final start = await QuicServer.start(
      QuicServerConfig(
        bindAddress: '127.0.0.1:0',
        certificateChainPem: File(cert).readAsStringSync(),
        privateKeyPem: File(key).readAsStringSync(),
        idleTimeout: const Duration(seconds: 30),
      ),
      candidatePaths: [path],
    );
    expect(start.status, RkQuicStatus.ok, reason: '${start.detail}');
    return start.server!;
  }

  test('a failing call does not hand its status to a call beside it', () async {
    final server = await startServer();

    // Two calls in flight at once, with different true answers: a write to a
    // session that never existed is `unknownHandle`, stopping a running
    // endpoint is `ok`. Neither awaits the other — exactly how a till writes.
    final write = server.sendOn(424242, 4, 'nobody is listening');
    final stop = server.stop();

    expect(await write, RkQuicStatus.unknownHandle);
    expect(
      await stop,
      RkQuicStatus.ok,
      reason:
          'stop was answered with the reply meant for the write beside it — '
          'replies are matched by arrival, not by call',
    );
  });
}
