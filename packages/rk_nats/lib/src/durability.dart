/// What an acknowledgement means, and whether the caller agreed to it.
///
/// The authority for these rules is the native library; this is a mirror of
/// them, and `test/mirror_agreement_test.dart` compares the two decision by
/// decision so that they cannot drift apart unnoticed.
///
/// The mirror exists for a reason worth stating. A caller has to be able to
/// look at an ack and know what it bought without a round trip, and it has to
/// be able to reason about a policy before a connection exists — for instance
/// while validating a configuration screen. Deciding that on the Dart side and
/// deciding it again on the native side is not two implementations of a
/// feature; it is one contract, checked at both ends.
///
/// # The measurement behind all of this
///
/// Jepsen's audit of NATS 2.12.1 (2025-12-08) found JetStream acking a write
/// immediately and fsyncing on a timer, and lost about 14 % of acknowledged
/// messages to a coordinated power cut. Measured against real servers on
/// 2026-07-31: nats-server 2.14.4, the latest release, still ships
/// `sync_interval: 2m` by default.
library;

import 'codes.dart';

/// What the caller demands an ack to mean.
enum RkNatsDurability {
  /// **The default.** An ack means the message is fsynced to disk.
  ///
  /// Requires a server started with `sync_interval: "always"`, a file-backed
  /// stream, and a stream that is not in async persistence mode. If any of the
  /// three cannot be proved, publishing is refused rather than performed.
  ///
  /// Measured cost on one machine over loopback with one replica, publishing
  /// sequentially and awaiting each ack: 158 msg/s, against 2 902 msg/s for
  /// the same server with the default settings. Eighteen times slower, and
  /// still four times faster than a payment terminal.
  fsyncOnAck,

  /// An ack means the server has written the message but may not have fsynced
  /// it. Requires [RkNatsConnectOptions.acceptedFsyncLag] to be set: choosing
  /// this policy means naming how much acknowledged data you accept losing to
  /// a power cut, and the server's own window is checked against that number.
  flushOnAck,

  /// An ack means the server has it in RAM somewhere. The name is the warning.
  ackIsMemoryOnly,
}

/// What an ack actually means, given the server and the stream.
enum RkNatsAckMeaning {
  /// Nobody asked the server, or the answer could not be read.
  unknown,

  /// On disk, fsynced before the ack was sent.
  fsyncedToDisk,

  /// Written, with the fsync still to come on the server's timer.
  writtenNotFsynced,

  /// The stream acks before storing. The ack says nothing about a disk.
  ackedBeforeStore,

  /// The stream lives in memory.
  memoryOnly,
}

/// How a stream stores its messages.
enum RkNatsStorage {
  /// On disk.
  file,

  /// In the server's memory.
  memory,
}

/// A stream's persistence mode, as nats-server 2.14 and later understand it.
enum RkNatsPersistMode {
  /// The server's own default: the write is issued before the ack.
  ///
  /// Note the name is `default` on the wire but cannot be spelled that way in
  /// Dart, so [rkNatsPersistModeWireName] does the translation. This is the one
  /// place where a name differs between the two sides, and it is why that
  /// translation is a named function with a test rather than a string literal
  /// buried in a request builder.
  serverDefault,

  /// The ack may be sent before the message is stored.
  ///
  /// Measured: an `async` stream on a server configured to fsync every write
  /// ran at 4 198 msg/s, against 158 msg/s for a default-mode stream on the
  /// same server. It is not waiting for the disk, and its ack looks identical
  /// to one that is.
  async,
}

/// The name a persistence mode goes by on the wire.
String rkNatsPersistModeWireName(RkNatsPersistMode mode) => switch (mode) {
  RkNatsPersistMode.serverDefault => 'default',
  RkNatsPersistMode.async => 'async',
};

/// Reads a persistence mode back from its wire name.
RkNatsPersistMode? rkNatsPersistModeFromWireName(Object? name) =>
    switch (name) {
      'default' => RkNatsPersistMode.serverDefault,
      'async' => RkNatsPersistMode.async,
      _ => null,
    };

/// Reads an ack meaning from the name the native library sent. An unknown name
/// becomes [RkNatsAckMeaning.unknown] — never something reassuring.
RkNatsAckMeaning rkNatsAckMeaningFromName(Object? name) {
  if (name is! String) return RkNatsAckMeaning.unknown;
  for (final meaning in RkNatsAckMeaning.values) {
    if (meaning.name == name) return meaning;
  }
  return RkNatsAckMeaning.unknown;
}

/// What a server said about its own durability.
class RkNatsServerDurability {
  /// Builds the facts.
  const RkNatsServerDurability({
    required this.version,
    required this.syncAlways,
    required this.syncInterval,
    required this.storeDir,
  });

  /// Reads the facts out of the native library's reply.
  factory RkNatsServerDurability.fromJson(Map<String, Object?> json) =>
      RkNatsServerDurability(
        version: json['version'] as String? ?? '',
        syncAlways: json['syncAlways'] as bool? ?? false,
        syncInterval: Duration(
          microseconds: ((json['syncIntervalNanos'] as num?) ?? 0) ~/ 1000,
        ),
        storeDir: json['storeDir'] as String? ?? '',
      );

  /// The server's version, recorded and not used to decide anything: behaviour
  /// is detected, never inferred from a number.
  final String version;

  /// True when the server was started with `sync_interval: "always"`. This, and
  /// only this, is what makes an ack mean fsynced.
  final bool syncAlways;

  /// The server's fsync timer. **Meaningful only when [syncAlways] is false.**
  ///
  /// Measured on 2.14.4: turning fsync-on-write on leaves this field at two
  /// minutes. A check that read this field alone would call a safe server
  /// unsafe.
  final Duration syncInterval;

  /// Where the server keeps its store, so a diagnostic can name the filesystem
  /// the whole promise rests on.
  final String storeDir;

  @override
  String toString() =>
      'RkNatsServerDurability(version: $version, syncAlways: $syncAlways, '
      'syncInterval: $syncInterval, storeDir: $storeDir)';
}

/// What an ack means on this server, for a stream configured this way.
///
/// The order of the tests is the substance. A stream that acks before storing
/// says nothing about disks however the server is configured, so that test
/// comes first and a caller cannot buy safety back by fixing the server alone.
RkNatsAckMeaning rkNatsAckMeaning({
  required RkNatsServerDurability? server,
  required RkNatsStorage storage,
  required RkNatsPersistMode persistMode,
}) {
  if (server == null) return RkNatsAckMeaning.unknown;
  if (storage == RkNatsStorage.memory) return RkNatsAckMeaning.memoryOnly;
  if (persistMode == RkNatsPersistMode.async) {
    return RkNatsAckMeaning.ackedBeforeStore;
  }
  if (server.syncAlways) return RkNatsAckMeaning.fsyncedToDisk;
  return RkNatsAckMeaning.writtenNotFsynced;
}

/// Whether an ack that means [meaning] may be given to a caller who asked for
/// [policy], and if not, which failure to report.
///
/// Returns `null` when the ack is good enough.
RkNatsCode? rkNatsGate({
  required RkNatsDurability policy,
  required RkNatsAckMeaning meaning,
  required Duration acceptedFsyncLag,
  RkNatsServerDurability? server,
}) {
  switch (policy) {
    // Promises nothing, so nothing can violate it. The escape hatch, spelled
    // out loud.
    case RkNatsDurability.ackIsMemoryOnly:
      return null;

    case RkNatsDurability.fsyncOnAck:
      return switch (meaning) {
        RkNatsAckMeaning.fsyncedToDisk => null,
        RkNatsAckMeaning.unknown => RkNatsCode.durabilityUnproven,
        _ => RkNatsCode.durabilityWeakerThanRequested,
      };

    case RkNatsDurability.flushOnAck:
      switch (meaning) {
        case RkNatsAckMeaning.fsyncedToDisk:
          return null;
        case RkNatsAckMeaning.unknown:
          return RkNatsCode.durabilityUnproven;
        case RkNatsAckMeaning.writtenNotFsynced:
          // Without the server we do not know its window, and an unknown
          // window is not a short one.
          final window = server?.syncInterval;
          if (window == null || window > acceptedFsyncLag) {
            return RkNatsCode.fsyncLagTooLong;
          }
          return null;
        case RkNatsAckMeaning.ackedBeforeStore:
        case RkNatsAckMeaning.memoryOnly:
          return RkNatsCode.durabilityWeakerThanRequested;
      }
  }
}
