//! Whole messages: the twelve-byte header and the four sections.
//!
//! Parsing is total. Anything on the multicast group can send anything, and a
//! responder that panicked on a bad datagram would be a till that stopped
//! being findable because somebody else's device is buggy. Every failure here
//! is a returned [`ParseError`], and the responder's answer to one is silence.

use crate::name::{Name, NameError};
use crate::record::{decode_data, encode_record, Question, Record, TOP_BIT};

/// `QR` — this message is a response.
pub const FLAG_RESPONSE: u16 = 0x8000;
/// `AA` — the sender is authoritative for what it says.
pub const FLAG_AUTHORITATIVE: u16 = 0x0400;
/// `TC` — truncated; more known answers follow (RFC 6762 §7.2).
pub const FLAG_TRUNCATED: u16 = 0x0200;

/// A parsed message.
#[derive(Debug, Clone, Default)]
pub struct Message {
    /// Always zero in multicast DNS, kept because a unicast reply must echo it.
    pub id: u16,
    /// The header flags, whole.
    pub flags: u16,
    /// What is being asked.
    pub questions: Vec<Question>,
    /// What is being answered.
    pub answers: Vec<Record>,
    /// The authority section. During a probe this carries the records the
    /// prober intends to claim (RFC 6762 §8.2), which is what makes tie-breaking
    /// possible.
    pub authority: Vec<Record>,
    /// The additional section.
    pub additional: Vec<Record>,
}

impl Message {
    /// Whether this is somebody's answer rather than somebody's question.
    pub fn is_response(&self) -> bool {
        self.flags & FLAG_RESPONSE != 0
    }

    /// Whether the sender claims authority for what it says.
    pub fn is_authoritative(&self) -> bool {
        self.flags & FLAG_AUTHORITATIVE != 0
    }

    /// Whether more known answers are coming in a follow-up datagram.
    pub fn is_truncated(&self) -> bool {
        self.flags & FLAG_TRUNCATED != 0
    }

    /// A response carrying `answers`, authoritative, with no questions.
    pub fn response(answers: Vec<Record>) -> Message {
        Message {
            id: 0,
            flags: FLAG_RESPONSE | FLAG_AUTHORITATIVE,
            questions: Vec::new(),
            answers,
            authority: Vec::new(),
            additional: Vec::new(),
        }
    }

    /// A query for `questions`, carrying `known` as suppression (RFC 6762 §7.1).
    pub fn query(questions: Vec<Question>, known: Vec<Record>) -> Message {
        Message {
            id: 0,
            flags: 0,
            questions,
            answers: known,
            authority: Vec::new(),
            additional: Vec::new(),
        }
    }

    /// Writes the message.
    ///
    /// No compression pointers are produced — see [`Name::encode`]. The result
    /// is a few dozen bytes larger and readable by everything.
    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(512);
        out.extend_from_slice(&self.id.to_be_bytes());
        out.extend_from_slice(&self.flags.to_be_bytes());
        out.extend_from_slice(&(self.questions.len() as u16).to_be_bytes());
        out.extend_from_slice(&(self.answers.len() as u16).to_be_bytes());
        out.extend_from_slice(&(self.authority.len() as u16).to_be_bytes());
        out.extend_from_slice(&(self.additional.len() as u16).to_be_bytes());

        for question in &self.questions {
            question.name.encode(&mut out);
            out.extend_from_slice(&question.qtype.to_be_bytes());
            let class = if question.unicast_response {
                question.qclass | TOP_BIT
            } else {
                question.qclass
            };
            out.extend_from_slice(&class.to_be_bytes());
        }
        for section in [&self.answers, &self.authority, &self.additional] {
            for record in section {
                encode_record(record, &mut out);
            }
        }
        out
    }

    /// Reads a message, or says why it could not.
    pub fn decode(message: &[u8]) -> Result<Message, ParseError> {
        if message.len() < 12 {
            return Err(ParseError::TooShort(message.len()));
        }
        let id = u16::from_be_bytes([message[0], message[1]]);
        let flags = u16::from_be_bytes([message[2], message[3]]);
        let counts = [
            u16::from_be_bytes([message[4], message[5]]) as usize,
            u16::from_be_bytes([message[6], message[7]]) as usize,
            u16::from_be_bytes([message[8], message[9]]) as usize,
            u16::from_be_bytes([message[10], message[11]]) as usize,
        ];

        let mut offset = 12usize;
        let mut questions = Vec::with_capacity(counts[0].min(64));
        for _ in 0..counts[0] {
            let (name, next) = Name::decode(message, offset)?;
            if next + 4 > message.len() {
                return Err(ParseError::Name(NameError::Truncated));
            }
            let qtype = u16::from_be_bytes([message[next], message[next + 1]]);
            let raw_class = u16::from_be_bytes([message[next + 2], message[next + 3]]);
            questions.push(Question {
                name,
                qtype,
                qclass: raw_class & !TOP_BIT,
                unicast_response: raw_class & TOP_BIT != 0,
            });
            offset = next + 4;
        }

        let mut sections: [Vec<Record>; 3] = Default::default();
        for (index, count) in counts[1..].iter().enumerate() {
            let mut records = Vec::with_capacity((*count).min(64));
            for _ in 0..*count {
                let (name, next) = Name::decode(message, offset)?;
                if next + 10 > message.len() {
                    return Err(ParseError::Name(NameError::Truncated));
                }
                let rtype = u16::from_be_bytes([message[next], message[next + 1]]);
                let raw_class = u16::from_be_bytes([message[next + 2], message[next + 3]]);
                let ttl = u32::from_be_bytes([
                    message[next + 4],
                    message[next + 5],
                    message[next + 6],
                    message[next + 7],
                ]);
                let rdlength = u16::from_be_bytes([message[next + 8], message[next + 9]]) as usize;
                let data = decode_data(message, rtype, next + 10, rdlength)?;
                records.push(Record {
                    name,
                    class: raw_class & !TOP_BIT,
                    ttl,
                    cache_flush: raw_class & TOP_BIT != 0,
                    data,
                });
                offset = next + 10 + rdlength;
            }
            sections[index] = records;
        }

        let [answers, authority, additional] = sections;
        Ok(Message {
            id,
            flags,
            questions,
            answers,
            authority,
            additional,
        })
    }
}

/// Why a datagram could not be read as a message.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParseError {
    /// Shorter than a header.
    TooShort(usize),
    /// A name inside it could not be read.
    Name(NameError),
}

impl From<NameError> for ParseError {
    fn from(error: NameError) -> Self {
        ParseError::Name(error)
    }
}

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ParseError::TooShort(n) => write!(f, "{n} bytes, shorter than a DNS header"),
            ParseError::Name(e) => write!(f, "{e}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::record::{rtype, RecordData, CLASS_IN};

    fn n(text: &str) -> Name {
        Name::parse(text).expect("test name parses")
    }

    #[test]
    fn a_response_survives_a_round_trip_with_every_record_type() {
        let message = Message::response(vec![
            Record::shared(
                n("_telepos._tcp.local"),
                4500,
                RecordData::Ptr(n("till-3._telepos._tcp.local")),
            ),
            Record::flushing(
                n("till-3._telepos._tcp.local"),
                120,
                RecordData::Srv {
                    priority: 0,
                    weight: 0,
                    port: 8443,
                    target: n("till-3.local"),
                },
            ),
            Record::flushing(
                n("till-3._telepos._tcp.local"),
                4500,
                RecordData::Txt(vec![b"quic=4433".to_vec()]),
            ),
            Record::flushing(n("till-3.local"), 120, RecordData::A([10, 0, 0, 7].into())),
            Record::flushing(
                n("till-3.local"),
                120,
                RecordData::Aaaa("fe80::1".parse().unwrap()),
            ),
        ]);

        let read = Message::decode(&message.encode()).expect("decodes");
        assert!(read.is_response());
        assert!(read.is_authoritative());
        assert_eq!(read.answers.len(), 5);
        for (before, after) in message.answers.iter().zip(read.answers.iter()) {
            assert_eq!(before.data, after.data);
            assert_eq!(before.ttl, after.ttl);
            assert_eq!(before.cache_flush, after.cache_flush);
        }
    }

    #[test]
    fn the_qu_bit_is_read_out_of_the_class_and_not_left_in_it() {
        // The top bit means "reply to me directly" in a question and
        // "cache-flush" in an answer. Leaving it in `qclass` would make every
        // QU question compare unequal to IN and be ignored.
        let query = Message::query(
            vec![Question {
                name: n("till-3.local"),
                qtype: rtype::A,
                qclass: CLASS_IN,
                unicast_response: true,
            }],
            Vec::new(),
        );
        let read = Message::decode(&query.encode()).expect("decodes");
        assert!(read.questions[0].unicast_response);
        assert_eq!(read.questions[0].qclass, CLASS_IN);
    }

    #[test]
    fn the_cache_flush_bit_is_read_out_of_an_answer_class() {
        let message = Message::response(vec![Record::flushing(
            n("till-3.local"),
            120,
            RecordData::A([10, 0, 0, 7].into()),
        )]);
        let read = Message::decode(&message.encode()).expect("decodes");
        assert!(read.answers[0].cache_flush);
        assert_eq!(read.answers[0].class, CLASS_IN);
    }

    #[test]
    fn known_answers_ride_in_the_answer_section_of_a_query() {
        // RFC 6762 §7.1. A browser that sent them in `additional` would be
        // suppressing nothing, and every responder on the segment would answer
        // every repeat.
        let known = Record::shared(
            n("_telepos._tcp.local"),
            4500,
            RecordData::Ptr(n("till-3._telepos._tcp.local")),
        );
        let query = Message::query(
            vec![Question {
                name: n("_telepos._tcp.local"),
                qtype: rtype::PTR,
                qclass: CLASS_IN,
                unicast_response: false,
            }],
            vec![known.clone()],
        );
        let read = Message::decode(&query.encode()).expect("decodes");
        assert!(!read.is_response());
        assert_eq!(read.questions.len(), 1);
        assert_eq!(read.answers.len(), 1);
        assert!(read.answers[0].same_answer(&known));
    }

    #[test]
    fn a_probe_carries_its_proposed_records_in_the_authority_section() {
        // RFC 6762 §8.2: this is what makes tie-breaking possible at all.
        let mut probe = Message::query(
            vec![Question {
                name: n("till-3.local"),
                qtype: rtype::ANY,
                qclass: CLASS_IN,
                unicast_response: true,
            }],
            Vec::new(),
        );
        probe.authority = vec![Record::flushing(
            n("till-3.local"),
            120,
            RecordData::A([10, 0, 0, 7].into()),
        )];
        let read = Message::decode(&probe.encode()).expect("decodes");
        assert_eq!(read.authority.len(), 1);
        assert!(read.answers.is_empty());
    }

    #[test]
    fn a_short_datagram_is_refused_rather_than_read() {
        assert_eq!(Message::decode(&[]).unwrap_err(), ParseError::TooShort(0));
        assert_eq!(
            Message::decode(&[0u8; 11]).unwrap_err(),
            ParseError::TooShort(11)
        );
    }

    #[test]
    fn a_header_that_lies_about_its_counts_is_an_error_and_not_a_panic() {
        // The most ordinary hostile datagram: a header claiming 65535 questions
        // with nothing behind it. Every branch below has to end in an error.
        let mut message = vec![0u8; 12];
        message[4] = 0xff;
        message[5] = 0xff;
        assert!(Message::decode(&message).is_err());

        let mut message = vec![0u8; 12];
        message[6] = 0xff;
        message[7] = 0xff;
        assert!(Message::decode(&message).is_err());
    }

    #[test]
    fn random_bytes_never_panic() {
        // Not a proof, a floor. The socket is open to the whole segment.
        let mut state = 0x1234_5678_9abc_def0u64;
        for _ in 0..2000 {
            let mut buffer = Vec::new();
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            let len = (state % 300) as usize;
            for i in 0..len {
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                buffer.push((state >> (i % 8 * 8)) as u8);
            }
            let _ = Message::decode(&buffer);
        }
    }
}
