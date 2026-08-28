import 'dart:convert';

/// Something that happened on the endpoint.
///
/// The native side sends a `kind` **name**, and it is resolved by name here
/// (И147). A kind this build does not know becomes [UnknownQuicEvent] rather
/// than the nearest match — a newer library talking to an older Dart side must
/// degrade to "I do not know what that was", never to the wrong branch.
sealed class QuicEvent {
  const QuicEvent();

  /// Parses one event. Never throws: malformed JSON from the native side is a
  /// bug worth *seeing*, and an exception out of a background isolate is the
  /// least visible way to report it.
  factory QuicEvent.fromJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      return UnknownQuicEvent(
        kind: '<unparsable>',
        raw: json,
        detail: '$error',
      );
    }
    if (decoded is! Map<String, Object?>) {
      return UnknownQuicEvent(
        kind: '<not an object>',
        raw: json,
        detail: 'expected a JSON object',
      );
    }

    final kind = decoded['kind'];
    if (kind is! String) {
      return UnknownQuicEvent(kind: '<no kind>', raw: json);
    }

    // `is` and not `as`: a cast throws on a field of the wrong type, and this
    // factory promises never to throw. It runs on the poll isolate, where an
    // exception is reported nowhere and takes the event loop with it — so a
    // library sending `"sessionId":"7"` would silence the transport instead of
    // producing one odd event. A missing or mistyped field reads as absent.
    final fields = decoded;
    int number(String key) {
      final value = fields[key];
      return value is int ? value : -1;
    }

    String text(String key) {
      final value = fields[key];
      return value is String ? value : '';
    }

    return switch (kind) {
      'sessionOpened' => SessionOpened(
        sessionId: number('sessionId'),
        authority: text('authority'),
        path: text('path'),
      ),
      'sessionClosed' => SessionClosed(
        sessionId: number('sessionId'),
        reason: text('reason'),
      ),
      'datagram' => DatagramReceived(
        sessionId: number('sessionId'),
        message: text('utf8'),
      ),
      'streamMessage' => StreamMessageReceived(
        sessionId: number('sessionId'),
        message: text('utf8'),
      ),
      'streamOpened' => StreamOpened(
        sessionId: number('sessionId'),
        streamId: number('streamId'),
      ),
      'streamData' => StreamData(
        sessionId: number('sessionId'),
        streamId: number('streamId'),
        message: text('utf8'),
      ),
      'streamClosed' => StreamClosed(
        sessionId: number('sessionId'),
        streamId: number('streamId'),
      ),
      'endpointError' => EndpointError(message: text('message')),
      _ => UnknownQuicEvent(kind: kind, raw: json),
    };
  }
}

/// A browser opened a WebTransport session.
final class SessionOpened extends QuicEvent {
  const SessionOpened({
    required this.sessionId,
    required this.authority,
    required this.path,
  });

  final int sessionId;

  /// The host the client believes it reached.
  final String authority;
  final String path;

  @override
  String toString() => 'SessionOpened($sessionId, $authority$path)';
}

/// A session ended — politely, or because the peer stopped answering.
///
/// One event for both, because the consequence is the same: writing to it is
/// now pointless, and anything queued for it has to go somewhere else.
final class SessionClosed extends QuicEvent {
  const SessionClosed({required this.sessionId, required this.reason});

  final int sessionId;
  final String reason;

  @override
  String toString() => 'SessionClosed($sessionId, $reason)';
}

/// A datagram arrived: unordered, droppable.
final class DatagramReceived extends QuicEvent {
  const DatagramReceived({required this.sessionId, required this.message});

  final int sessionId;
  final String message;

  @override
  String toString() => 'DatagramReceived($sessionId, ${message.length} chars)';
}

/// A complete message arrived on a stream: ordered, retransmitted.
final class StreamMessageReceived extends QuicEvent {
  const StreamMessageReceived({required this.sessionId, required this.message});

  final int sessionId;
  final String message;

  @override
  String toString() =>
      'StreamMessageReceived($sessionId, ${message.length} chars)';
}

/// A peer opened a bidirectional stream.
///
/// [streamId] is on this and on both events that follow because a session is
/// not an exchange: a browser can have several questions in flight at once, and
/// only the stream says which answer belongs to which.
final class StreamOpened extends QuicEvent {
  const StreamOpened({required this.sessionId, required this.streamId});

  final int sessionId;
  final int streamId;

  @override
  String toString() => 'StreamOpened($sessionId, stream $streamId)';
}

/// A complete message arrived on a bidirectional stream.
///
/// Unlike [StreamMessageReceived] the exchange is not over: the endpoint's own
/// half is still writable, so this is the point at which a question can be
/// answered, a subscription started, or a run begun.
final class StreamData extends QuicEvent {
  const StreamData({
    required this.sessionId,
    required this.streamId,
    required this.message,
  });

  final int sessionId;
  final int streamId;
  final String message;

  @override
  String toString() =>
      'StreamData($sessionId, stream $streamId, ${message.length} chars)';
}

/// The peer finished **its** side of a bidirectional stream.
///
/// ## This is not an unsubscribe, and reading it as one is a trap
///
/// The endpoint reads a message to its end before reporting it, so it only
/// learns of a request once the client has already finished writing. This event
/// therefore arrives immediately behind [StreamData] — identically for a
/// one-off question and for a subscription meant to last an hour. Treating it
/// as "the client went away" would cancel every subscription the moment it was
/// created.
///
/// A peer that really has gone is learned two other ways: a write refused with
/// `RkQuicStatus.peerGone`, and [SessionClosed].
///
/// What it does mean is narrow and still useful: nothing more will arrive on
/// this stream, so a caller waiting for further input can stop waiting.
final class StreamClosed extends QuicEvent {
  const StreamClosed({required this.sessionId, required this.streamId});

  final int sessionId;
  final int streamId;

  @override
  String toString() => 'StreamClosed($sessionId, stream $streamId)';
}

/// The endpoint hit trouble of its own. Still a valid handle; still has to be
/// stopped.
final class EndpointError extends QuicEvent {
  const EndpointError({required this.message});

  final String message;

  @override
  String toString() => 'EndpointError($message)';
}

/// A kind this build does not know, kept whole.
///
/// Deliberately not dropped: an event nobody can read is still evidence that
/// the two sides disagree, and silently discarding it turns a version mismatch
/// into "the feature does not work".
final class UnknownQuicEvent extends QuicEvent {
  const UnknownQuicEvent({required this.kind, required this.raw, this.detail});

  final String kind;
  final String raw;
  final String? detail;

  @override
  String toString() =>
      'UnknownQuicEvent($kind${detail == null ? '' : ', $detail'})';
}
