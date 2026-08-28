// The browser half of the conditional import in `responder.dart`.
//
// A browser cannot host an mDNS responder: it has no UDP socket, no way to
// join a multicast group, and no `dart:ffi` to reach one through. This is not
// a stub waiting to be filled in — it is the permanent, correct answer, and
// the reason `flutter build web` keeps passing (И143).
//
// The surface matches `responder_io.dart` exactly, so a caller compiled for
// both does not have to know which half it got.

import 'dart:async';

import 'mdns_event.dart';
import 'service.dart';
import 'status.dart';

/// Always [RkMdnsStatus.unsupported] here, with the reason stated.
class MdnsResponderStart {
  const MdnsResponderStart._(this.status, this.responder, this.detail);

  /// What happened.
  final RkMdnsStatus status;

  /// Always null here.
  final MdnsResponder? responder;

  /// One line for a log.
  final String? detail;

  /// Whether the responder is running. Always false here.
  bool get isOk => status == RkMdnsStatus.ok;

  @override
  String toString() =>
      'MdnsResponderStart(${status.name}${detail == null ? '' : ', $detail'})';
}

/// The shape of a responder, for a platform that cannot host one.
class MdnsResponder {
  MdnsResponder._();

  /// Never produces anything.
  Stream<ResponderEvent> get events => const Stream<ResponderEvent>.empty();

  /// An empty state, never claimed.
  ResponderState get initialState => const ResponderState(
    instance: '',
    host: '',
    addresses: <String>[],
    claimed: false,
    interfaces: <InterfaceReport>[],
  );

  /// Always false: there is no name to hold.
  Future<bool> get hasRequestedName async => false;

  /// Never starts, never throws.
  static Future<MdnsResponderStart> start(
    ServiceAnnouncement announcement, {
    List<String>? candidatePaths,
  }) async {
    return const MdnsResponderStart._(
      RkMdnsStatus.unsupported,
      null,
      'a browser cannot answer mDNS: it has no UDP socket and no multicast '
      'group to join. Ask a host that has one, over HTTP or WebTransport.',
    );
  }

  /// Always null.
  Future<ResponderState?> state() async => null;

  /// Always [RkMdnsStatus.unsupported].
  Future<RkMdnsStatus> stop() async => RkMdnsStatus.unsupported;
}
