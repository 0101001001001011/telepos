@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_mdns/rk_mdns.dart';

/// Reading events is the only place this package parses anything on the Dart
/// side, and it reads what a background isolate sent. A parse that threw would
/// take the whole stream down over one bad message, so every case here is
/// about *not* doing that.
void main() {
  group('responder events', () {
    test('each kind becomes its own class with its fields intact', () {
      final probing = ResponderEvent.fromJson(
        '{"kind":"probing","instance":"till-3._telepos._tcp.local",'
        '"host":"till-3.local","attempt":2}',
      );
      expect(probing, isA<ProbingName>());
      expect((probing as ProbingName).attempt, 2);
      expect(probing.host, 'till-3.local');

      final conflict = ResponderEvent.fromJson(
        '{"kind":"nameConflict","from":"till-3._t._tcp.local",'
        '"to":"till-3-2._t._tcp.local","detail":"another host answered"}',
      );
      expect(conflict, isA<NameConflict>());
      expect((conflict as NameConflict).to, 'till-3-2._t._tcp.local');
      expect(conflict.detail, 'another host answered');

      final claimed = ResponderEvent.fromJson(
        '{"kind":"claimed","instance":"a","host":"b",'
        '"addresses":["10.0.0.7","fe80::1"],"interfaces":3}',
      );
      expect(claimed, isA<NameClaimed>());
      expect((claimed as NameClaimed).addresses, ['10.0.0.7', 'fe80::1']);
      expect(claimed.interfaces, 3);

      final announced = ResponderEvent.fromJson(
        '{"kind":"announced","carried":4,"interfaces":5}',
      );
      expect(announced, isA<Announced>());
      expect((announced as Announced).carried, 4);
      expect(announced.interfaces, 5);

      final answered = ResponderEvent.fromJson(
        '{"kind":"answered","question":"till-3.local A","to":"10.0.0.9:5353",'
        '"unicast":true,"answers":1}',
      );
      expect(answered, isA<Answered>());
      expect((answered as Answered).unicast, isTrue);

      expect(
        ResponderEvent.fromJson('{"kind":"goodbye","carried":2}'),
        isA<Goodbye>(),
      );
      expect(
        ResponderEvent.fromJson('{"kind":"error","detail":"gave up"}'),
        isA<MdnsError>(),
      );
    });

    test('a kind this build does not know is kept whole, not dropped', () {
      // A newer native library may send a kind this Dart side has no class
      // for. The correct answer is "something happened I do not understand"
      // with the JSON attached — not a dropped event and not a wrong branch.
      const json = '{"kind":"somethingFrom2027","detail":"x"}';
      final event = ResponderEvent.fromJson(json);
      expect(event, isA<UnknownMdnsEvent>());
      expect((event as UnknownMdnsEvent).json, json);
    });

    test('malformed input is an event, never an exception', () {
      for (final bad in const [
        '',
        'not json',
        '[]',
        '{',
        'null',
        '{"kind":42}',
      ]) {
        expect(
          ResponderEvent.fromJson(bad),
          isA<UnknownMdnsEvent>(),
          reason: 'input: "$bad"',
        );
      }
    });

    test('a field of the wrong type falls back rather than throwing', () {
      // The native side would not send this, but a stream that dies on one
      // surprising message is worse than one that reports a zero.
      final event = ResponderEvent.fromJson(
        '{"kind":"announced","carried":"four","interfaces":null}',
      );
      expect(event, isA<Announced>());
      expect((event as Announced).carried, 0);
      expect(event.interfaces, 0);
    });
  });

  group('browser events', () {
    test('a resolved service carries everything needed to connect', () {
      final event = BrowserEvent.fromJson(
        '{"kind":"serviceResolved","instance":"till-3._telepos._tcp.local",'
        '"host":"till-3.local","port":8443,"addresses":["10.0.0.7"],'
        '"txt":[{"key":"quic","value":"4433"},{"key":"flag","value":""}]}',
      );
      expect(event, isA<ServiceResolved>());
      final resolved = event as ServiceResolved;
      expect(resolved.host, 'till-3.local');
      expect(resolved.port, 8443);
      expect(resolved.addresses, ['10.0.0.7']);
      expect(resolved.txt, const [
        TxtEntry('quic', '4433'),
        TxtEntry('flag', ''),
      ]);
    });

    test('an absent TXT key and a valueless one are different answers', () {
      // RFC 6763 §6.4. A caller checking for a flag has to tell "the key is
      // there with no value" from "nobody sent that key", and a bare `?? ''`
      // on the Dart side would erase the difference.
      final resolved =
          BrowserEvent.fromJson(
                '{"kind":"serviceResolved","instance":"a","host":"b",'
                '"port":1,"addresses":["10.0.0.1"],'
                '"txt":[{"key":"flag","value":""}]}',
              )
              as ServiceResolved;
      expect(resolved['flag'], '');
      expect(resolved['missing'], isNull);
    });

    test('found and lost are distinct kinds', () {
      expect(
        BrowserEvent.fromJson('{"kind":"serviceFound","instance":"a"}'),
        isA<ServiceFound>(),
      );
      expect(
        BrowserEvent.fromJson('{"kind":"serviceLost","instance":"a"}'),
        isA<ServiceLost>(),
      );
      expect(
        BrowserEvent.fromJson('{"kind":"queried","carried":1,"interfaces":1}'),
        isA<Queried>(),
      );
    });

    test('malformed input is an event, never an exception', () {
      for (final bad in const ['', 'not json', '[1,2]', '{"kind":null}']) {
        expect(
          BrowserEvent.fromJson(bad),
          isA<UnknownMdnsEvent>(),
          reason: 'input: "$bad"',
        );
      }
    });
  });

  group('the configuration a caller writes', () {
    test('an announcement produces the keys the native side reads', () {
      final json = const ServiceAnnouncement(
        instanceName: 'till-3',
        serviceType: '_telepos._tcp.local',
        port: 8443,
        txt: ['quic=4433'],
      ).toJson();

      expect(json['instanceName'], 'till-3');
      expect(json['serviceType'], '_telepos._tcp.local');
      expect(json['port'], 8443);
      expect(json['txt'], ['quic=4433']);
      // Durations cross as whole seconds, because a TTL is defined in them.
      expect(json['hostTtlSeconds'], 120);
      expect(json['serviceTtlSeconds'], 4500);
      expect(json['mdnsPort'], 5353);
      expect(json['probe'], isTrue);
      // An absent host name is left out rather than sent as null: the native
      // side refuses unknown keys and derives the default itself.
      expect(json.containsKey('hostName'), isFalse);
    });

    test('an explicit host name is passed through', () {
      final json = const ServiceAnnouncement(
        instanceName: 'till-3',
        serviceType: '_telepos._tcp.local',
        port: 8443,
        hostName: 'kassa.local',
      ).toJson();
      expect(json['hostName'], 'kassa.local');
    });

    test('a host query carries its timeout in milliseconds', () {
      final json = const HostQuery(
        hostName: 'till-3.local',
        timeout: Duration(milliseconds: 1500),
      ).toJson();
      expect(json['hostName'], 'till-3.local');
      expect(json['timeoutMs'], 1500);
    });
  });

  group('what the native side reports back', () {
    test('a responder state reads its interfaces', () {
      final state = ResponderState.fromJson(const {
        'instance': 'till-3._telepos._tcp.local',
        'host': 'till-3.local',
        'addresses': ['10.0.0.7'],
        'claimed': true,
        'interfaces': [
          {
            'name': 'eth0',
            'address': '10.0.0.7',
            'index': 2,
            'sent': 6,
            'failed': 0,
          },
        ],
      });
      expect(state.claimed, isTrue);
      expect(state.interfaces.single.name, 'eth0');
      expect(state.interfaces.single.sent, 6);
    });

    test('a state with fields missing reads as empty rather than throwing', () {
      final state = ResponderState.fromJson(const <String, Object?>{});
      expect(state.instance, '');
      expect(state.interfaces, isEmpty);
      expect(state.claimed, isFalse);
    });
  });
}
