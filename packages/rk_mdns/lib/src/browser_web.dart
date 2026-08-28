// The browser half of the conditional import in `browser.dart`.
//
// A browser has no UDP socket and no multicast group to join, so it can
// neither answer mDNS nor ask it. The surface matches `browser_io.dart`
// exactly, so a caller compiled for both does not have to know which half it
// got (И143).

import 'dart:async';

import 'mdns_event.dart';
import 'service.dart';
import 'status.dart';

/// Always [RkMdnsStatus.unsupported] here, with the reason stated.
class MdnsBrowserStart {
  const MdnsBrowserStart._(this.status, this.browser, this.detail);

  /// What happened.
  final RkMdnsStatus status;

  /// Always null here.
  final MdnsBrowser? browser;

  /// One line for a log.
  final String? detail;

  /// Whether the browser is running. Always false here.
  bool get isOk => status == RkMdnsStatus.ok;

  @override
  String toString() =>
      'MdnsBrowserStart(${status.name}${detail == null ? '' : ', $detail'})';
}

/// The shape of a browse, for a platform that cannot make one.
class MdnsBrowser {
  MdnsBrowser._();

  /// Never produces anything.
  Stream<BrowserEvent> get events => const Stream<BrowserEvent>.empty();

  /// Never starts, never throws.
  static Future<MdnsBrowserStart> start(
    BrowseRequest request, {
    List<String>? candidatePaths,
  }) async {
    return const MdnsBrowserStart._(
      RkMdnsStatus.unsupported,
      null,
      'a browser cannot ask mDNS: there is no UDP socket and no multicast '
      'group to join. Ask a host that has one, over HTTP or WebTransport.',
    );
  }

  /// Always [RkMdnsStatus.unsupported].
  Future<RkMdnsStatus> stop() async => RkMdnsStatus.unsupported;
}

/// Always null: there is nothing here to ask with.
///
/// Null rather than an empty [HostAddresses], and the difference is the point:
/// an empty answer means "asked, nobody replied", which a browser never gets
/// to find out.
Future<HostAddresses?> resolveHost(
  HostQuery query, {
  List<String>? candidatePaths,
}) async => null;

/// Always null: a browser cannot enumerate the host's interfaces.
Future<List<MdnsInterface>?> mdnsInterfaces({
  bool includeLoopback = false,
  List<String>? candidatePaths,
}) async => null;
