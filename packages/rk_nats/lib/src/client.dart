/// The public surface: connecting, streams, publishing, consuming.
library;

import 'dart:convert';

import 'codes.dart';
import 'durability.dart';
import 'native_library.dart';
import 'options.dart';
import 'worker.dart';

/// The outcome of a call: either a value or a code, never a thrown protocol
/// failure (I144).
///
/// Deliberately not a pair of exceptions. A till that cannot reach its server
/// is an ordinary Tuesday, and ordinary Tuesdays should not travel by
/// exception through code that is holding a transaction open.
class RkNatsResult<T> {
  /// A success.
  const RkNatsResult.ok(this.value) : code = RkNatsCode.ok, message = '';

  /// A failure.
  const RkNatsResult.failure(this.code, this.message) : value = null;

  /// The code. [RkNatsCode.ok] exactly when [value] is present.
  final RkNatsCode code;

  /// Something a human can read. Never the only thing returned.
  final String message;

  /// The value, when there is one.
  final T? value;

  /// Whether the call succeeded.
  bool get isOk => code == RkNatsCode.ok;

  @override
  String toString() => isOk
      ? 'RkNatsResult.ok($value)'
      : 'RkNatsResult.failure($code: $message)';
}

/// What the server said about itself, and what that makes an ack mean.
class RkNatsDurabilityReport {
  /// Builds it.
  const RkNatsDurabilityReport({
    required this.code,
    required this.message,
    required this.ackMeaning,
    required this.server,
  });

  /// Reads it out of a native reply.
  factory RkNatsDurabilityReport.fromJson(Map<String, Object?> json) {
    final server = json['server'];
    return RkNatsDurabilityReport(
      code: rkNatsCodeFromName(json['code'] ?? 'ok'),
      message: json['message'] as String? ?? '',
      ackMeaning: rkNatsAckMeaningFromName(json['ackMeaning']),
      server: server is Map<String, Object?>
          ? RkNatsServerDurability.fromJson(server)
          : null,
    );
  }

  /// Whether the probe succeeded.
  final RkNatsCode code;

  /// Why it did not, when it did not.
  final String message;

  /// What an ack on a plain file-backed stream would mean here.
  final RkNatsAckMeaning ackMeaning;

  /// The facts, when they were obtained.
  final RkNatsServerDurability? server;

  @override
  String toString() => 'RkNatsDurabilityReport($code, $ackMeaning, $server)';
}

/// What a stream turned out to be after the server echoed its configuration.
class RkNatsStreamInfo {
  /// Builds it.
  const RkNatsStreamInfo({
    required this.name,
    required this.storage,
    required this.requestedPersistMode,
    required this.effectivePersistMode,
    required this.persistModeHonoured,
    required this.replicas,
    required this.ackMeaning,
  });

  /// Reads it out of a native reply.
  factory RkNatsStreamInfo.fromJson(Map<String, Object?> json) =>
      RkNatsStreamInfo(
        name: json['stream'] as String? ?? '',
        storage: json['storage'] == 'memory'
            ? RkNatsStorage.memory
            : RkNatsStorage.file,
        requestedPersistMode:
            rkNatsPersistModeFromWireName(json['requestedPersistMode']) ??
            RkNatsPersistMode.serverDefault,
        effectivePersistMode:
            rkNatsPersistModeFromWireName(json['effectivePersistMode']) ??
            RkNatsPersistMode.serverDefault,
        persistModeHonoured: json['persistModeHonoured'] as bool? ?? false,
        replicas: (json['replicas'] as num?)?.toInt() ?? 1,
        ackMeaning: rkNatsAckMeaningFromName(json['ackMeaning']),
      );

  /// Stream name.
  final String name;

  /// Where it stores messages.
  final RkNatsStorage storage;

  /// What was asked for.
  final RkNatsPersistMode requestedPersistMode;

  /// What is actually in force.
  ///
  /// Not the same thing as [requestedPersistMode]: measured on nats-server
  /// 2.11.0, a stream created with `persist_mode: "async"` comes back with the
  /// field absent and no error at all.
  final RkNatsPersistMode effectivePersistMode;

  /// Whether the server honoured the persistence mode that was asked for.
  final bool persistModeHonoured;

  /// How many replicas the server made.
  final int replicas;

  /// What an ack from this stream means.
  final RkNatsAckMeaning ackMeaning;

  @override
  String toString() =>
      'RkNatsStreamInfo($name, $storage, '
      '$effectivePersistMode, ack means $ackMeaning)';
}

/// A successful publish, and what its acknowledgement meant.
class RkNatsPublishAck {
  /// Builds it.
  const RkNatsPublishAck({
    required this.stream,
    required this.sequence,
    required this.duplicate,
    required this.ackMeaning,
  });

  /// Reads it out of a native reply.
  factory RkNatsPublishAck.fromJson(Map<String, Object?> json) =>
      RkNatsPublishAck(
        stream: json['stream'] as String? ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        duplicate: json['duplicate'] as bool? ?? false,
        ackMeaning: rkNatsAckMeaningFromName(json['ackMeaning']),
      );

  /// The stream that took it.
  final String stream;

  /// Its position in that stream.
  final int sequence;

  /// True when the server recognised the message id as one it already has.
  /// A retry that comes back `true` did not sell anything twice.
  final bool duplicate;

  /// **What this acknowledgement means.**
  ///
  /// Present on every single ack, not only at setup, and that is the point: a
  /// caller can assert on it at the moment it matters instead of trusting that
  /// nothing about the server changed since the connection was opened.
  final RkNatsAckMeaning ackMeaning;

  @override
  String toString() =>
      'RkNatsPublishAck($stream#$sequence, duplicate: $duplicate, '
      'means $ackMeaning)';
}

/// A message handed to a consumer.
class RkNatsMessage {
  /// Builds it.
  const RkNatsMessage({
    required this.subject,
    required this.payload,
    required this.replySubject,
    required this.streamSequence,
    required this.numDelivered,
  });

  /// Reads it out of a native reply.
  factory RkNatsMessage.fromJson(Map<String, Object?> json) => RkNatsMessage(
    subject: json['subject'] as String? ?? '',
    payload: base64Decode(json['payloadBase64'] as String? ?? ''),
    replySubject: json['replySubject'] as String? ?? '',
    streamSequence: (json['streamSequence'] as num?)?.toInt() ?? 0,
    numDelivered: (json['numDelivered'] as num?)?.toInt() ?? 0,
  );

  /// The subject it arrived on.
  final String subject;

  /// The body.
  final List<int> payload;

  /// Where its acknowledgement goes.
  final String replySubject;

  /// Its position in the stream.
  final int streamSequence;

  /// How many times this consumer has been given it. More than one means an
  /// earlier delivery went unacknowledged.
  final int numDelivered;

  @override
  String toString() =>
      'RkNatsMessage($subject #$streamSequence, '
      '${payload.length} bytes, delivered $numDelivered time(s))';
}

/// A connection to NATS, with a durability contract attached.
///
/// Every call goes through a worker isolate, so nothing here runs on the
/// isolate that draws the screen (I145).
class RkNatsClient {
  RkNatsClient._(this._worker, this._handle, this.durability, this.policy);

  /// Opens a connection.
  ///
  /// [libraryPath] is the native library. How that file gets onto the machine
  /// is a separate decision, made once for every `rk_*` package, and this
  /// binding deliberately does not make it.
  ///
  /// The durability probe runs here, so that by the time anything is published
  /// the answer is already known or already refused.
  static Future<RkNatsResult<RkNatsClient>> connect(
    RkNatsConnectOptions options, {
    required String libraryPath,
  }) async {
    final problem = options.problem;
    if (problem != null) {
      return RkNatsResult.failure(problem, _explain(options));
    }

    final RkNatsWorker worker;
    try {
      worker = await RkNatsWorker.start(libraryPath);
    } on RkNatsLibraryUnavailable catch (error) {
      return RkNatsResult.failure(RkNatsCode.connectFailed, error.message);
    }

    final reply = await worker.call(RkNatsSymbols.connect, options.toJson());
    final code = rkNatsCodeFromName(reply['code']);
    if (code != RkNatsCode.ok) {
      await worker.stop();
      return RkNatsResult.failure(code, reply['message'] as String? ?? '');
    }

    final durabilityJson = reply['durability'];
    final report = durabilityJson is Map<String, Object?>
        ? RkNatsDurabilityReport.fromJson(durabilityJson)
        : const RkNatsDurabilityReport(
            code: RkNatsCode.durabilityUnproven,
            message: 'the library returned no durability report',
            ackMeaning: RkNatsAckMeaning.unknown,
            server: null,
          );

    return RkNatsResult.ok(
      RkNatsClient._(
        worker,
        (reply['handle'] as num).toInt(),
        report,
        options.durability,
      ),
    );
  }

  static String _explain(RkNatsConnectOptions options) {
    if (options.servers.isEmpty) return 'connect needs at least one server URL';
    return 'policy ${options.durability.name} requires acceptedFsyncLag to be '
        'set: the point of choosing it is to state how much acknowledged data '
        'you accept losing to a power cut';
  }

  final RkNatsWorker _worker;
  final int _handle;

  /// What the server said about itself when the connection was opened.
  ///
  /// Worth reading even on success: it names the machine, the store directory
  /// and the fsync setting the whole promise rests on.
  final RkNatsDurabilityReport durability;

  /// The policy this connection was opened with.
  final RkNatsDurability policy;

  /// What an ack on a plain file-backed stream means on this connection.
  RkNatsAckMeaning get ackMeaning => durability.ackMeaning;

  /// Whether this connection can currently satisfy its own policy.
  ///
  /// False here means every publish will be refused, and it says so before a
  /// caller writes the code that discovers it.
  bool get satisfiesPolicy =>
      rkNatsGate(
        policy: policy,
        meaning: durability.ackMeaning,
        acceptedFsyncLag: durability.server?.syncInterval ?? Duration.zero,
        server: durability.server,
      ) ==
      null;

  /// Hands the library a `varz` document fetched by the caller, after the fact.
  ///
  /// For the case where the monitoring port only becomes reachable later, or
  /// where a diagnostic wants to re-check a long-lived connection.
  Future<RkNatsResult<RkNatsDurabilityReport>> applyVarz(String varz) async {
    final reply = await _worker.call(RkNatsSymbols.applyVarz, {
      'handle': _handle,
      'varz': varz,
    });
    return _map(reply, RkNatsDurabilityReport.fromJson);
  }

  /// Asks the server again, through the evidence path given at connect.
  Future<RkNatsResult<RkNatsDurabilityReport>> probeDurability({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final reply = await _worker.call(RkNatsSymbols.probeDurability, {
      'handle': _handle,
      'timeoutMillis': timeout.inMilliseconds,
    });
    return _map(reply, RkNatsDurabilityReport.fromJson);
  }

  /// Creates a stream, or brings an existing one to this shape.
  ///
  /// Refused, without creating anything, when the resulting stream could not
  /// satisfy this connection's policy. A refusal leaves nothing behind on the
  /// server to clean up.
  Future<RkNatsResult<RkNatsStreamInfo>> ensureStream(
    RkNatsStreamOptions options,
  ) async {
    final reply = await _worker.call(
      RkNatsSymbols.ensureStream,
      options.toJson(_handle),
    );
    return _map(reply, RkNatsStreamInfo.fromJson);
  }

  /// Publishes one message and waits for the acknowledgement.
  ///
  /// [stream] is required: durability is a property of a stream, so a publish
  /// that does not name one cannot be judged, and the server's answer is
  /// checked against it in case a subject landed somewhere unexpected.
  ///
  /// [messageId] makes a retry safe. Inside the stream's duplicate window the
  /// server recognises the same id as the same message and answers
  /// [RkNatsPublishAck.duplicate].
  Future<RkNatsResult<RkNatsPublishAck>> publish({
    required String stream,
    required String subject,
    required List<int> payload,
    String messageId = '',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final reply = await _worker.call(RkNatsSymbols.publish, {
      'handle': _handle,
      'stream': stream,
      'subject': subject,
      'payloadBase64': base64Encode(payload),
      'messageId': messageId,
      'timeoutMillis': timeout.inMilliseconds,
    });
    return _map(reply, RkNatsPublishAck.fromJson);
  }

  /// Pulls a batch from a durable consumer, creating the consumer if needed.
  Future<RkNatsResult<List<RkNatsMessage>>> fetch({
    required String stream,
    required String consumer,
    String filterSubject = '',
    int batch = 16,
    Duration expires = const Duration(seconds: 1),
  }) async {
    final reply = await _worker.call(RkNatsSymbols.fetch, {
      'handle': _handle,
      'stream': stream,
      'consumer': consumer,
      'filterSubject': filterSubject,
      'batch': batch,
      'expiresMillis': expires.inMilliseconds,
    });
    return _map(reply, (json) {
      final messages = json['messages'] as List<Object?>? ?? const [];
      return messages
          .cast<Map<String, Object?>>()
          .map(RkNatsMessage.fromJson)
          .toList(growable: false);
    });
  }

  /// Acknowledges a delivered message.
  ///
  /// [doubleAck] waits for the server to confirm it recorded the
  /// acknowledgement. On by default, because an unconfirmed ack has exactly the
  /// "probably" problem this package exists to remove.
  Future<RkNatsResult<bool>> ack(
    RkNatsMessage message, {
    bool doubleAck = true,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final reply = await _worker.call(RkNatsSymbols.ack, {
      'handle': _handle,
      'replySubject': message.replySubject,
      'doubleAck': doubleAck,
      'timeoutMillis': timeout.inMilliseconds,
    });
    return _map(reply, (json) => json['acknowledged'] as bool? ?? false);
  }

  /// Closes the connection and stops the worker isolate.
  ///
  /// Deterministic (I146): the native handle is dropped here, not whenever a
  /// collector notices this object is unreachable.
  Future<void> close() async {
    await _worker.call(RkNatsSymbols.close, {'handle': _handle});
    await _worker.stop();
  }

  static RkNatsResult<T> _map<T>(
    Map<String, Object?> reply,
    T Function(Map<String, Object?>) build,
  ) {
    final code = rkNatsCodeFromName(reply['code']);
    if (code != RkNatsCode.ok) {
      return RkNatsResult.failure(code, reply['message'] as String? ?? '');
    }
    return RkNatsResult.ok(build(reply));
  }
}

/// Reads a `varz` document and says what an ack would mean on that server,
/// without connecting to anything.
///
/// Useful before a connection exists: a setup screen can hold a document up and
/// say "this server will lose up to two minutes of acknowledged sales" while
/// the operator is still deciding.
Future<RkNatsResult<RkNatsDurabilityReport>> rkNatsEvaluateVarz(
  String varz, {
  required String libraryPath,
}) async {
  final RkNatsWorker worker;
  try {
    worker = await RkNatsWorker.start(libraryPath);
  } on RkNatsLibraryUnavailable catch (error) {
    return RkNatsResult.failure(RkNatsCode.connectFailed, error.message);
  }
  try {
    final reply = await worker.call(RkNatsSymbols.evaluateVarz, {'varz': varz});
    return RkNatsClient._map(reply, RkNatsDurabilityReport.fromJson);
  } finally {
    await worker.stop();
  }
}
