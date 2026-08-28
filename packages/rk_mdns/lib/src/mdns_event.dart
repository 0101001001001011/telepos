/// What the responder and the browser report as it happens.
///
/// **The `kind` crosses as a name, never as a number (И147).** A kind this
/// build does not know becomes [UnknownMdnsEvent] carrying the raw JSON,
/// rather than being dropped or mistaken for a neighbour — so an older Dart
/// side against a newer library degrades to "something happened I do not
/// understand" instead of to a wrong branch.
///
/// Pure Dart: this file is shared with the browser half and must compile where
/// `dart:ffi` does not exist (И143).
library;

import 'dart:convert';

import 'service.dart';

/// Anything the responder says.
sealed class ResponderEvent {
  /// The base of the responder's event hierarchy.
  const ResponderEvent();

  /// Reads one event out of the JSON the native side wrote.
  ///
  /// Never throws. Malformed JSON becomes [UnknownMdnsEvent]: this reads what
  /// a background isolate sent, and a parse that threw would take the stream
  /// down over one bad message.
  static ResponderEvent fromJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on Object {
      return UnknownMdnsEvent(json);
    }
    if (decoded is! Map<String, Object?>) return UnknownMdnsEvent(json);
    return switch (decoded['kind']) {
      'probing' => ProbingName(
        instance: _text(decoded['instance']),
        host: _text(decoded['host']),
        attempt: _int(decoded['attempt']),
      ),
      'nameConflict' => NameConflict(
        from: _text(decoded['from']),
        to: _text(decoded['to']),
        detail: _text(decoded['detail']),
      ),
      'claimed' => NameClaimed(
        instance: _text(decoded['instance']),
        host: _text(decoded['host']),
        addresses: _strings(decoded['addresses']),
        interfaces: _int(decoded['interfaces']),
      ),
      'announced' => Announced(
        carried: _int(decoded['carried']),
        interfaces: _int(decoded['interfaces']),
      ),
      'answered' => Answered(
        question: _text(decoded['question']),
        to: _text(decoded['to']),
        unicast: _flag(decoded['unicast']),
        answers: _int(decoded['answers']),
      ),
      'goodbye' => Goodbye(carried: _int(decoded['carried'])),
      'error' => MdnsError(_text(decoded['detail'])),
      _ => UnknownMdnsEvent(json),
    };
  }
}

/// A probe went out (RFC 6762 §8.1).
class ProbingName extends ResponderEvent {
  /// Which name, and which of the three probes.
  const ProbingName({
    required this.instance,
    required this.host,
    required this.attempt,
  });

  /// The instance name being claimed.
  final String instance;

  /// The host name being claimed.
  final String host;

  /// Which of the three this was, from 1.
  final int attempt;

  @override
  String toString() => 'ProbingName($instance / $host, attempt $attempt)';
}

/// Somebody else holds the name, and this responder moved.
///
/// The event that matters most here. Two hosts named alike is a setup mistake
/// this package **can** detect, and reporting it is the difference between a
/// visible misconfiguration and a tablet reaching whichever answered first.
class NameConflict extends ResponderEvent {
  /// What was contested, what was taken instead, and why.
  const NameConflict({
    required this.from,
    required this.to,
    required this.detail,
  });

  /// The name that was contested.
  final String from;

  /// The name taken instead — `till-3` becomes `till-3-2`.
  final String to;

  /// Who or what the conflict was with.
  final String detail;

  @override
  String toString() => 'NameConflict($from -> $to: $detail)';
}

/// The names are claimed and the records are live.
class NameClaimed extends ResponderEvent {
  /// The names and addresses this responder ended up announcing.
  const NameClaimed({
    required this.instance,
    required this.host,
    required this.addresses,
    required this.interfaces,
  });

  /// The instance name in the end.
  final String instance;

  /// The host name in the end.
  final String host;

  /// What the address records carry.
  final List<String> addresses;

  /// How many interfaces the records go out on.
  final int interfaces;

  @override
  String toString() =>
      'NameClaimed($instance at $host, $addresses, $interfaces interfaces)';
}

/// An announcement went out (RFC 6762 §8.3).
class Announced extends ResponderEvent {
  /// How many interfaces carried it, of how many.
  const Announced({required this.carried, required this.interfaces});

  /// How many interfaces carried it.
  final int carried;

  /// How many were offered it. `carried` below this means an interface is
  /// refusing the send.
  final int interfaces;

  @override
  String toString() => 'Announced($carried of $interfaces interfaces)';
}

/// A question was answered.
class Answered extends ResponderEvent {
  /// What was asked, by whom, and how the reply went.
  const Answered({
    required this.question,
    required this.to,
    required this.unicast,
    required this.answers,
  });

  /// What was asked.
  final String question;

  /// Who asked.
  final String to;

  /// Whether the reply went straight back rather than to the group — the `QU`
  /// bit of RFC 6762 §5.4.
  final bool unicast;

  /// How many records went in the answer section.
  final int answers;

  @override
  String toString() =>
      'Answered($question to $to, ${unicast ? 'unicast' : 'multicast'}, '
      '$answers records)';
}

/// The goodbye went out and the responder is done (RFC 6762 §10.1).
class Goodbye extends ResponderEvent {
  /// How many interfaces carried it.
  const Goodbye({required this.carried});

  /// How many interfaces carried it.
  final int carried;

  @override
  String toString() => 'Goodbye($carried interfaces)';
}

/// Anything the browser says.
sealed class BrowserEvent {
  /// The base of the browser's event hierarchy.
  const BrowserEvent();

  /// Reads one event out of the JSON the native side wrote. Never throws.
  static BrowserEvent fromJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on Object {
      return UnknownMdnsEvent(json);
    }
    if (decoded is! Map<String, Object?>) return UnknownMdnsEvent(json);
    return switch (decoded['kind']) {
      'serviceFound' => ServiceFound(_text(decoded['instance'])),
      'serviceResolved' => ServiceResolved(
        instance: _text(decoded['instance']),
        host: _text(decoded['host']),
        port: _int(decoded['port']),
        addresses: _strings(decoded['addresses']),
        txt: _txt(decoded['txt']),
      ),
      'serviceLost' => ServiceLost(_text(decoded['instance'])),
      'queried' => Queried(
        carried: _int(decoded['carried']),
        interfaces: _int(decoded['interfaces']),
      ),
      'error' => MdnsError(_text(decoded['detail'])),
      _ => UnknownMdnsEvent(json),
    };
  }
}

/// A service instance exists. Its details may not be known yet.
class ServiceFound extends BrowserEvent {
  /// The instance name.
  const ServiceFound(this.instance);

  /// `till-3._telepos._tcp.local`.
  final String instance;

  @override
  String toString() => 'ServiceFound($instance)';
}

/// Enough is known to connect: a host, a port and at least one address.
///
/// Sent only when all three are there. A service reported earlier would put an
/// entry in an operator's list that fails at the first tap, which is worse
/// than an entry that is a moment late.
class ServiceResolved extends BrowserEvent {
  /// Everything needed to open a connection.
  const ServiceResolved({
    required this.instance,
    required this.host,
    required this.port,
    required this.addresses,
    required this.txt,
  });

  /// `till-3._telepos._tcp.local`.
  final String instance;

  /// The host name out of the `SRV`.
  final String host;

  /// The port out of the `SRV`.
  final int port;

  /// What the `A` and `AAAA` records carry.
  final List<String> addresses;

  /// The `TXT` record, already split.
  final List<TxtEntry> txt;

  /// The value for `key`, or null when the key is absent.
  ///
  /// Null and empty are different answers: RFC 6763 §6.4 defines an entry with
  /// no `=` as a key that is present with no value, and a caller checking for
  /// a flag needs to tell that from a key nobody sent.
  String? operator [](String key) {
    for (final entry in txt) {
      if (entry.key == key) return entry.value;
    }
    return null;
  }

  @override
  String toString() =>
      'ServiceResolved($instance at $host:$port, $addresses, $txt)';
}

/// The instance is gone — a goodbye arrived, or its records expired.
class ServiceLost extends BrowserEvent {
  /// The instance name.
  const ServiceLost(this.instance);

  /// `till-3._telepos._tcp.local`.
  final String instance;

  @override
  String toString() => 'ServiceLost($instance)';
}

/// A query went out.
class Queried extends BrowserEvent {
  /// How many interfaces carried it, of how many.
  const Queried({required this.carried, required this.interfaces});

  /// How many interfaces carried it.
  final int carried;

  /// How many were offered it.
  final int interfaces;

  @override
  String toString() => 'Queried($carried of $interfaces interfaces)';
}

/// Something went wrong that the caller is entitled to know about.
///
/// In both hierarchies, because both can produce it and a caller that handles
/// one should not have to write the branch twice.
class MdnsError extends ResponderEvent implements BrowserEvent {
  /// One line.
  const MdnsError(this.detail);

  /// One line.
  final String detail;

  @override
  String toString() => 'MdnsError($detail)';
}

/// A kind this build does not know, kept whole.
///
/// Not a failure. A newer native library may send a kind this Dart side has no
/// class for, and the correct answer is "something happened I do not
/// understand" with the JSON attached — not a dropped event and not a wrong
/// branch.
class UnknownMdnsEvent extends ResponderEvent implements BrowserEvent {
  /// The raw JSON, exactly as it arrived.
  const UnknownMdnsEvent(this.json);

  /// The raw JSON.
  final String json;

  @override
  String toString() => 'UnknownMdnsEvent($json)';
}

// Every field is read leniently, and that is not laziness about types.
//
// This parses what a background isolate sent over a port. A cast that threw
// would take the whole event stream down over one surprising field — and the
// caller would lose every later event, including the goodbye, for a value it
// might not even read. A zero or an empty string is recoverable; a dead stream
// is not.

int _int(Object? value) => value is num ? value.toInt() : 0;

String _text(Object? value) => value is String ? value : '';

bool _flag(Object? value) => value is bool && value;

List<String> _strings(Object? value) => value is List<Object?>
    ? value.map((e) => e.toString()).toList(growable: false)
    : const <String>[];

List<TxtEntry> _txt(Object? value) {
  if (value is! List<Object?>) return const <TxtEntry>[];
  final entries = <TxtEntry>[];
  for (final item in value) {
    if (item is! Map<Object?, Object?>) continue;
    entries.add(
      TxtEntry(item['key']?.toString() ?? '', item['value']?.toString() ?? ''),
    );
  }
  return List<TxtEntry>.unmodifiable(entries);
}
