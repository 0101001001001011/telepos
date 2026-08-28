@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';

/// The events a bidirectional exchange produces, and why the stream is on all
/// three of them.
///
/// The one-way events in `server_test.dart` carry a session and nothing else,
/// which is enough when nobody is going to answer. These carry a stream as
/// well, because a browser can have several exchanges open on one session at
/// the same time and a reply has to say which question it belongs to.
void main() {
  group('a bidirectional exchange is named by its stream, not its session', () {
    test('streamData carries the stream an answer has to go back into', () {
      final event = QuicEvent.fromJson(
        '{"kind":"streamData","sessionId":7,"streamId":3,"utf8":"{}"}',
      );

      expect(event, isA<StreamData>());
      final data = event as StreamData;
      expect(data.sessionId, 7);
      expect(data.streamId, 3);
      expect(data.message, '{}');
    });

    test('streamOpened and streamClosed carry the same pair', () {
      expect(
        QuicEvent.fromJson(
          '{"kind":"streamOpened","sessionId":7,"streamId":3}',
        ),
        isA<StreamOpened>()
            .having((e) => e.sessionId, 'sessionId', 7)
            .having((e) => e.streamId, 'streamId', 3),
      );
      expect(
        QuicEvent.fromJson(
          '{"kind":"streamClosed","sessionId":7,"streamId":3}',
        ),
        isA<StreamClosed>()
            .having((e) => e.sessionId, 'sessionId', 7)
            .having((e) => e.streamId, 'streamId', 3),
      );
    });

    test('a two-way message is never mistaken for a one-way one', () {
      // `streamMessage` and `streamData` differ by one word on the wire and by
      // everything in consequence: one arrived on a stream that is already
      // over, the other on a stream that can still be written to. Resolving
      // either to the other's type would send an answer nowhere.
      expect(
        QuicEvent.fromJson('{"kind":"streamMessage","sessionId":7,"utf8":"x"}'),
        isA<StreamMessageReceived>(),
      );
      expect(
        QuicEvent.fromJson(
          '{"kind":"streamData","sessionId":7,"streamId":3,"utf8":"x"}',
        ),
        isA<StreamData>(),
      );
    });

    test('a frame with no streamId is an event, not an exception', () {
      // A library newer or older than this wrapper is an ordinary state in the
      // field. Reading a missing field as null and throwing would take down
      // the poll isolate, where nothing is watching to report it.
      for (final json in <String>[
        '{"kind":"streamOpened","sessionId":7}',
        '{"kind":"streamData","sessionId":7,"utf8":"x"}',
        '{"kind":"streamClosed"}',
        '{"kind":"streamData","sessionId":"seven","streamId":"three"}',
      ]) {
        expect(() => QuicEvent.fromJson(json), returnsNormally, reason: json);
        expect(QuicEvent.fromJson(json), isNot(isA<UnknownQuicEvent>()));
      }
    });
  });
}
