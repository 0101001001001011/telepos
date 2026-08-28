/// The requests, as things a caller builds rather than JSON it assembles.
library;

import 'codes.dart';
import 'durability.dart';

/// How to authenticate to NATS.
sealed class RkNatsCredentials {
  const RkNatsCredentials();

  /// The wire form.
  Map<String, Object?> toJson();
}

/// No authentication.
class RkNatsNoCredentials extends RkNatsCredentials {
  /// Builds it.
  const RkNatsNoCredentials();

  @override
  Map<String, Object?> toJson() => {'kind': 'none'};
}

/// A user and a password.
class RkNatsUserPassword extends RkNatsCredentials {
  /// Builds it.
  const RkNatsUserPassword({required this.user, required this.password});

  /// User name.
  final String user;

  /// Password.
  final String password;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'userPassword',
    'user': user,
    'password': password,
  };
}

/// A bare token.
class RkNatsToken extends RkNatsCredentials {
  /// Builds it.
  const RkNatsToken(this.token);

  /// The token.
  final String token;

  @override
  Map<String, Object?> toJson() => {'kind': 'token', 'token': token};
}

/// A `.creds` file on disk.
class RkNatsCredsFile extends RkNatsCredentials {
  /// Builds it.
  const RkNatsCredsFile(this.path);

  /// Path to the file.
  final String path;

  @override
  Map<String, Object?> toJson() => {'kind': 'credsFile', 'path': path};
}

/// How the caller proposes to prove what an ack means on this server.
///
/// There is no fourth option that means "assume it is fine". The absence is the
/// design: a durability promise nobody checked is the defect this package was
/// written against.
sealed class RkNatsDurabilityEvidence {
  const RkNatsDurabilityEvidence();

  /// The wire form.
  Map<String, Object?> toJson();
}

/// Nothing at all.
///
/// Legal, and it makes every ack mean [RkNatsAckMeaning.unknown], which
/// [RkNatsDurability.fsyncOnAck] and [RkNatsDurability.flushOnAck] both refuse.
/// Pair it with [RkNatsDurability.ackIsMemoryOnly] or expect a refusal.
class RkNatsNoEvidence extends RkNatsDurabilityEvidence {
  /// Builds it.
  const RkNatsNoEvidence();

  @override
  Map<String, Object?> toJson() => {'kind': 'none'};
}

/// A `varz` document the caller fetched itself, usually from the server's
/// monitoring port.
///
/// The fetching stays on this side on purpose: it keeps an HTTP stack out of
/// the native library, and it keeps the evidence a thing a human can print and
/// put in a ticket.
class RkNatsVarzEvidence extends RkNatsDurabilityEvidence {
  /// Builds it from the raw document.
  const RkNatsVarzEvidence(this.varz);

  /// The document, exactly as the server served it.
  final String varz;

  @override
  Map<String, Object?> toJson() => {'kind': 'varzJson', 'varz': varz};
}

/// Credentials for an account that can see `$SYS`, so the library can ask the
/// server over NATS.
///
/// The path to use where the monitoring port is closed, which on an appliance
/// it should be.
class RkNatsSystemAccountEvidence extends RkNatsDurabilityEvidence {
  /// Builds it.
  const RkNatsSystemAccountEvidence({
    required this.user,
    required this.password,
  });

  /// System-account user.
  final String user;

  /// System-account password.
  final String password;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'systemAccount',
    'user': user,
    'password': password,
  };
}

/// Everything needed to open a connection.
class RkNatsConnectOptions {
  /// Builds the options.
  ///
  /// [durability] defaults to [RkNatsDurability.fsyncOnAck]. That default is
  /// the point of the package: the weaker settings exist, and taking one means
  /// naming it here, in the caller's own source, where a reviewer can see it.
  const RkNatsConnectOptions({
    required this.servers,
    this.name = '',
    this.credentials = const RkNatsNoCredentials(),
    this.durability = RkNatsDurability.fsyncOnAck,
    this.acceptedFsyncLag,
    this.evidence = const RkNatsNoEvidence(),
    this.timeout = const Duration(seconds: 5),
  });

  /// Server URLs.
  final List<String> servers;

  /// The name this client reports to the server.
  final String name;

  /// How to authenticate.
  final RkNatsCredentials credentials;

  /// What an ack has to mean here.
  final RkNatsDurability durability;

  /// For [RkNatsDurability.flushOnAck] only: how much acknowledged-but-unsynced
  /// data the caller accepts losing to a power cut.
  final Duration? acceptedFsyncLag;

  /// How the server's durability is to be proved.
  final RkNatsDurabilityEvidence evidence;

  /// Deadline for the connect.
  final Duration timeout;

  /// The reason these options cannot be used, or `null` if they can.
  ///
  /// Checked here as well as in the native library so that a configuration
  /// screen can say what is wrong before anything is dialled.
  RkNatsCode? get problem {
    if (servers.isEmpty) return RkNatsCode.invalidRequest;
    if (durability == RkNatsDurability.flushOnAck &&
        (acceptedFsyncLag == null || acceptedFsyncLag == Duration.zero)) {
      // Choosing the weaker policy is allowed. Choosing it without saying how
      // much data you accept losing is the vague middle where "acknowledged"
      // quietly comes to mean "probably".
      return RkNatsCode.invalidRequest;
    }
    return null;
  }

  /// The wire form.
  Map<String, Object?> toJson() => {
    'servers': servers,
    'name': name,
    'credentials': credentials.toJson(),
    'policy': durability.name,
    'acceptedFsyncLagNanos':
        (acceptedFsyncLag ?? Duration.zero).inMicroseconds * 1000,
    'evidence': evidence.toJson(),
    'timeoutMillis': timeout.inMilliseconds,
  };
}

/// Everything needed to create a stream, or bring an existing one to shape.
class RkNatsStreamOptions {
  /// Builds the options.
  const RkNatsStreamOptions({
    required this.name,
    this.subjects = const [],
    this.storage = RkNatsStorage.file,
    this.persistMode = RkNatsPersistMode.serverDefault,
    this.replicas = 1,
    this.duplicateWindow = const Duration(minutes: 2),
    this.maxAge = Duration.zero,
    this.timeout = const Duration(seconds: 5),
  });

  /// Stream name.
  final String name;

  /// Subjects it captures. Empty means `name.>`.
  final List<String> subjects;

  /// File or memory.
  final RkNatsStorage storage;

  /// Default or async.
  final RkNatsPersistMode persistMode;

  /// How many replicas.
  ///
  /// More replicas is not a substitute for fsync. Jepsen found file corruption
  /// propagating through Raft and split brain after a single node failure, so
  /// replication protects against a machine dying, not against every machine
  /// having acked something it had not written.
  final int replicas;

  /// The window in which a repeated message id is recognised as the same
  /// message. This is what makes retrying a publish safe.
  final Duration duplicateWindow;

  /// Maximum age of a message, or zero for unlimited.
  final Duration maxAge;

  /// Deadline.
  final Duration timeout;

  /// The wire form, given the handle it belongs to.
  Map<String, Object?> toJson(int handle) => {
    'handle': handle,
    'name': name,
    'subjects': subjects,
    'storage': storage.name,
    'persistMode': rkNatsPersistModeWireName(persistMode),
    'replicas': replicas,
    'duplicateWindowNanos': duplicateWindow.inMicroseconds * 1000,
    'maxAgeNanos': maxAge.inMicroseconds * 1000,
    'timeoutMillis': timeout.inMilliseconds,
  };
}
