// The browser half of the conditional import in `server.dart`.
//
// A browser is the **client** of a WebTransport endpoint, never its host: it
// has no UDP socket to bind and no `dart:ffi` to reach one through. So this is
// not a stub waiting to be filled in — it is the permanent, correct answer,
// and the reason `flutter build web` keeps passing (И143).
//
// The surface matches `server_io.dart` exactly, so a caller compiled for both
// does not have to know which half it got.

import 'dart:async';

import 'quic_event.dart';
import 'status.dart';

/// Mirrors the native side so the two halves present one surface.
class QuicServerConfig {
  const QuicServerConfig({
    required this.bindAddress,
    required this.certificateChainPem,
    required this.privateKeyPem,
    this.path = '/rk',
    this.idleTimeout = const Duration(seconds: 30),
  });

  final String bindAddress;
  final String certificateChainPem;
  final String privateKeyPem;
  final String path;
  final Duration idleTimeout;

  Map<String, Object?> toJson() => {
    'bindAddress': bindAddress,
    'certificateChainPem': certificateChainPem,
    'privateKeyPem': privateKeyPem,
    'path': path,
    'idleTimeoutMs': idleTimeout.inMilliseconds,
  };
}

/// Always [RkQuicStatus.unsupported] here, with the reason stated.
class QuicServerStart {
  const QuicServerStart._(this.status, this.server, this.detail);

  final RkQuicStatus status;
  final QuicServer? server;
  final String? detail;

  bool get isOk => status == RkQuicStatus.ok;

  @override
  String toString() =>
      'QuicServerStart(${status.name}${detail == null ? '' : ', $detail'})';
}

/// The shape of an endpoint, for a platform that cannot host one.
class QuicServer {
  QuicServer._();

  int get port => 0;

  Stream<QuicEvent> get events => const Stream<QuicEvent>.empty();

  /// Never starts, never throws.
  static Future<QuicServerStart> start(
    QuicServerConfig config, {
    List<String>? candidatePaths,
  }) async {
    return const QuicServerStart._(
      RkQuicStatus.unsupported,
      null,
      'a browser cannot host a QUIC endpoint: there is no dart:ffi and no UDP '
      'socket to bind. Connect to one instead, with the WebTransport API.',
    );
  }

  Future<RkQuicStatus> send(
    int sessionId,
    String message, {
    bool reliable = true,
  }) async => RkQuicStatus.unsupported;

  /// Present so the two halves are one surface, never reachable here: without
  /// an endpoint there is no stream a peer could have opened on it.
  Future<RkQuicStatus> sendOn(
    int sessionId,
    int streamId,
    String message,
  ) async => RkQuicStatus.unsupported;

  Future<RkQuicStatus> closeStream(int sessionId, int streamId) async =>
      RkQuicStatus.unsupported;

  Future<RkQuicStatus> stop() async => RkQuicStatus.unsupported;
}
