//! What the endpoint tells the caller, and why the caller has to ask.
//!
//! The whole reason this package exists is that **the server can speak first**
//! — a print job changing state should reach a browser when it happens, not
//! when something next polls. But a native library cannot call *into* Dart
//! safely from an arbitrary thread, so the direction is inverted at the
//! boundary only: events are queued in Rust and drained by one Dart call that
//! blocks until there is something or the wait runs out.
//!
//! That is a queue with a reader, not a poll: nothing is asked of the network,
//! and an event that arrives during the wait wakes the reader immediately.

use serde::Serialize;

/// One thing that happened on the endpoint.
///
/// Serialised with an explicit `kind` **name**, never a numbered tag (И147). A
/// reader that meets an unknown kind must be able to say "unknown", and an
/// integer tag makes that impossible to distinguish from a wrong branch.
// `rename_all` renames the *variants*; `rename_all_fields` renames the fields
// inside them. Only the first was here at one point, and the tag came out
// right while every field stayed `snake_case` — the kind of half-correct that
// a test comparing only the tag would have passed.
#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(
    tag = "kind",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum Event {
    /// A browser opened a WebTransport session.
    SessionOpened {
        session_id: u64,
        /// The `:authority` the client asked for — the host it thinks it
        /// reached.
        authority: String,
        path: String,
    },
    /// A session ended. `peerGone` covers both the polite close and the wire
    /// going away: from the server's side the consequence is the same, which
    /// is that writing to it is now pointless.
    SessionClosed { session_id: u64, reason: String },
    /// A datagram arrived. Lossy by nature — this is the path for "the current
    /// value", never for "the next change".
    Datagram { session_id: u64, utf8: String },
    /// A complete message arrived on a unidirectional stream. Ordered and
    /// reliable — this is the path for changes that must not be dropped.
    StreamMessage { session_id: u64, utf8: String },
    /// A peer opened a bidirectional stream.
    ///
    /// Everything that follows belongs to *this* stream, and the answer has to
    /// go back into it — which is why the identity travels on every one of the
    /// three events and not only on the first. A session id alone would not do:
    /// a browser can have several exchanges in flight at once, and without the
    /// stream there is no way to say which reply answers which question.
    StreamOpened { session_id: u64, stream_id: u64 },
    /// A complete message arrived on a bidirectional stream.
    ///
    /// Unlike [`Event::StreamMessage`] the stream is not over: an exchange can
    /// be a question and an answer, a subscription that goes on producing, or
    /// a long run reporting its progress.
    StreamData {
        session_id: u64,
        stream_id: u64,
        utf8: String,
    },
    /// The peer finished its side of a bidirectional stream. For a subscription
    /// this *is* the unsubscribe, and it needs no message of its own — a tab
    /// that was closed cannot send one.
    StreamClosed { session_id: u64, stream_id: u64 },
    /// The endpoint stopped accepting because of an error of its own. The
    /// endpoint is still a valid handle and still has to be stopped.
    EndpointError { message: String },
}

impl Event {
    /// The name this event travels under, for tests that must not restate the
    /// serde attribute by hand.
    pub fn kind(&self) -> &'static str {
        match self {
            Event::SessionOpened { .. } => "sessionOpened",
            Event::SessionClosed { .. } => "sessionClosed",
            Event::Datagram { .. } => "datagram",
            Event::StreamMessage { .. } => "streamMessage",
            Event::StreamOpened { .. } => "streamOpened",
            Event::StreamData { .. } => "streamData",
            Event::StreamClosed { .. } => "streamClosed",
            Event::EndpointError { .. } => "endpointError",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_serialised_tag_is_the_name_this_type_claims() {
        let cases = vec![
            Event::SessionOpened {
                session_id: 1,
                authority: "till.local".into(),
                path: "/rk".into(),
            },
            Event::SessionClosed {
                session_id: 1,
                reason: "peer gone".into(),
            },
            Event::Datagram {
                session_id: 1,
                utf8: "x".into(),
            },
            Event::StreamMessage {
                session_id: 1,
                utf8: "x".into(),
            },
            Event::EndpointError {
                message: "x".into(),
            },
            Event::StreamOpened {
                session_id: 1,
                stream_id: 2,
            },
            Event::StreamData {
                session_id: 1,
                stream_id: 2,
                utf8: "x".into(),
            },
            Event::StreamClosed {
                session_id: 1,
                stream_id: 2,
            },
        ];
        for event in cases {
            let json: serde_json::Value =
                serde_json::from_str(&serde_json::to_string(&event).unwrap()).unwrap();
            assert_eq!(
                json["kind"].as_str().unwrap(),
                event.kind(),
                "the wire tag and Event::kind disagree for {event:?}"
            );
        }
    }

    #[test]
    fn bidirectional_events_carry_the_stream_they_belong_to() {
        // The identity of the stream is the whole reason a bidirectional
        // exchange exists: without it there is nothing to answer *into*, and
        // the till would have to guess which of a browser's open questions a
        // reply belongs to.
        let opened = Event::StreamOpened {
            session_id: 7,
            stream_id: 3,
        };
        assert_eq!(opened.kind(), "streamOpened");

        let json = serde_json::to_string(&Event::StreamData {
            session_id: 7,
            stream_id: 3,
            utf8: "{}".to_owned(),
        })
        .unwrap();
        assert!(json.contains("\"streamId\":3"), "no stream in the frame: {json}");
        assert!(
            json.contains("\"sessionId\":7"),
            "no session in the frame: {json}"
        );

        assert_eq!(
            Event::StreamClosed {
                session_id: 7,
                stream_id: 3,
            }
            .kind(),
            "streamClosed"
        );
    }

    #[test]
    fn fields_travel_in_camel_case_so_dart_reads_them_unchanged() {
        let json = serde_json::to_string(&Event::SessionOpened {
            session_id: 7,
            authority: "a".into(),
            path: "/rk".into(),
        })
        .unwrap();
        assert!(json.contains("\"sessionId\":7"), "{json}");
        assert!(!json.contains("session_id"), "{json}");
    }
}
