//! Resource records — the five kinds DNS-SD needs, and nothing else.
//!
//! An unknown type is kept as raw bytes rather than dropped. A browser that
//! discarded what it could not parse would also discard the record that says a
//! service went away, and the service would sit in the list until its TTL
//! expired minutes later.

use std::net::{Ipv4Addr, Ipv6Addr};

use crate::name::{Name, NameError};

/// Record types, by their IANA numbers.
pub mod rtype {
    /// IPv4 address.
    pub const A: u16 = 1;
    /// Pointer — service type to instance, in DNS-SD.
    pub const PTR: u16 = 12;
    /// Text — the key/value pairs of DNS-SD.
    pub const TXT: u16 = 16;
    /// IPv6 address.
    pub const AAAA: u16 = 28;
    /// Service — host and port.
    pub const SRV: u16 = 33;
    /// Next secure. Not produced here; recognised because the probe response
    /// of a conflicting responder may carry one.
    pub const NSEC: u16 = 47;
    /// Any type — what a probe asks for (RFC 6762 §8.1).
    pub const ANY: u16 = 255;
}

/// `IN`, the only class that matters here.
pub const CLASS_IN: u16 = 0x0001;

/// The top bit of the class field.
///
/// In a **question** it is `QU`: the querier is asking for a unicast reply
/// (RFC 6762 §5.4). In an **answer** it is the cache-flush bit (§10.2): the
/// receiver should drop what it holds for this name rather than add to it.
/// Same bit, two meanings, decided by which section of the message it is in —
/// which is why the two are named separately below rather than shared.
pub const TOP_BIT: u16 = 0x8000;

/// A question.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Question {
    /// What is being asked about.
    pub name: Name,
    /// Which record type. `ANY` during a probe.
    pub qtype: u16,
    /// The class with the top bit already stripped.
    pub qclass: u16,
    /// Whether the querier asked for a unicast reply (RFC 6762 §5.4).
    ///
    /// Honoured rather than ignored: a resolver on a network that filters
    /// multicast replies — several access points do — gets nothing at all
    /// otherwise, and the failure looks like an absent till.
    pub unicast_response: bool,
}

/// What a record carries.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RecordData {
    /// An IPv4 address.
    A(Ipv4Addr),
    /// An IPv6 address.
    Aaaa(Ipv6Addr),
    /// A name this one points at.
    Ptr(Name),
    /// Priority, weight, port, target.
    Srv {
        /// Priority. Zero here; DNS-SD has no use for it on one host.
        priority: u16,
        /// Weight. Zero, for the same reason.
        weight: u16,
        /// The TCP or UDP port the service listens on.
        port: u16,
        /// The host name that resolves to the addresses.
        target: Name,
    },
    /// Length-prefixed strings, each usually `key=value`.
    Txt(Vec<Vec<u8>>),
    /// Anything else, kept whole.
    Other {
        /// The IANA type number.
        rtype: u16,
        /// The record data, exactly as it arrived.
        data: Vec<u8>,
    },
}

impl RecordData {
    /// The IANA type number this data belongs to.
    pub fn rtype(&self) -> u16 {
        match self {
            RecordData::A(_) => rtype::A,
            RecordData::Aaaa(_) => rtype::AAAA,
            RecordData::Ptr(_) => rtype::PTR,
            RecordData::Srv { .. } => rtype::SRV,
            RecordData::Txt(_) => rtype::TXT,
            RecordData::Other { rtype, .. } => *rtype,
        }
    }

    fn encode(&self, out: &mut Vec<u8>) {
        match self {
            RecordData::A(addr) => out.extend_from_slice(&addr.octets()),
            RecordData::Aaaa(addr) => out.extend_from_slice(&addr.octets()),
            RecordData::Ptr(name) => name.encode(out),
            RecordData::Srv {
                priority,
                weight,
                port,
                target,
            } => {
                out.extend_from_slice(&priority.to_be_bytes());
                out.extend_from_slice(&weight.to_be_bytes());
                out.extend_from_slice(&port.to_be_bytes());
                target.encode(out);
            }
            RecordData::Txt(entries) => {
                if entries.is_empty() {
                    // RFC 6763 §6.1: an empty TXT is one zero-length string,
                    // not zero bytes. A truly empty rdata is illegal and some
                    // resolvers drop the whole record.
                    out.push(0);
                    return;
                }
                for entry in entries {
                    let len = entry.len().min(255);
                    out.push(len as u8);
                    out.extend_from_slice(&entry[..len]);
                }
            }
            RecordData::Other { data, .. } => out.extend_from_slice(data),
        }
    }
}

/// One resource record.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Record {
    /// The name this record is about.
    pub name: Name,
    /// The class with the top bit stripped.
    pub class: u16,
    /// Seconds a receiver may cache it. Zero is a goodbye (RFC 6762 §10.1).
    pub ttl: u32,
    /// Whether the cache-flush bit was set (RFC 6762 §10.2).
    pub cache_flush: bool,
    /// The payload.
    pub data: RecordData,
}

impl Record {
    /// A record with the cache-flush bit set — the ordinary case for a record
    /// only this host is authoritative for.
    pub fn flushing(name: Name, ttl: u32, data: RecordData) -> Record {
        Record {
            name,
            class: CLASS_IN,
            ttl,
            cache_flush: true,
            data,
        }
    }

    /// A record with the bit clear.
    ///
    /// Used for `PTR` on the service type, and the reason is not stylistic:
    /// several tills share that name, so flushing it would make each
    /// announcement erase the others out of every browser on the segment.
    pub fn shared(name: Name, ttl: u32, data: RecordData) -> Record {
        Record {
            name,
            class: CLASS_IN,
            ttl,
            cache_flush: false,
            data,
        }
    }

    /// The same record with a lifetime of zero — "forget this".
    pub fn as_goodbye(&self) -> Record {
        Record {
            ttl: 0,
            ..self.clone()
        }
    }

    /// Whether two records say the same thing about the same name, ignoring
    /// the lifetime. This is what known-answer suppression compares (RFC 6762
    /// §7.1) — a record with 3000 seconds left and the same one with 4500 are
    /// the same answer.
    pub fn same_answer(&self, other: &Record) -> bool {
        self.name.eq_ignore_case(&other.name)
            && self.class == other.class
            && self.data == other.data
    }

    fn encode(&self, out: &mut Vec<u8>) {
        self.name.encode(out);
        out.extend_from_slice(&self.data.rtype().to_be_bytes());
        let class = if self.cache_flush {
            self.class | TOP_BIT
        } else {
            self.class
        };
        out.extend_from_slice(&class.to_be_bytes());
        out.extend_from_slice(&self.ttl.to_be_bytes());
        // The length is not known until the data is written, so the two bytes
        // are reserved and filled in afterwards.
        let length_at = out.len();
        out.extend_from_slice(&[0, 0]);
        self.data.encode(out);
        let written = (out.len() - length_at - 2) as u16;
        out[length_at..length_at + 2].copy_from_slice(&written.to_be_bytes());
    }
}

/// Decodes the rdata of one record.
///
/// `message` is the whole datagram because `PTR` and `SRV` targets may use
/// compression pointers into it; `start`/`len` bound the rdata itself.
pub(crate) fn decode_data(
    message: &[u8],
    rtype: u16,
    start: usize,
    len: usize,
) -> Result<RecordData, NameError> {
    let end = start + len;
    if end > message.len() {
        return Err(NameError::Truncated);
    }
    let body = &message[start..end];
    Ok(match rtype {
        rtype::A if len == 4 => RecordData::A(Ipv4Addr::new(body[0], body[1], body[2], body[3])),
        rtype::AAAA if len == 16 => {
            let mut octets = [0u8; 16];
            octets.copy_from_slice(body);
            RecordData::Aaaa(Ipv6Addr::from(octets))
        }
        rtype::PTR => {
            let (name, _) = Name::decode(message, start)?;
            RecordData::Ptr(name)
        }
        rtype::SRV if len >= 7 => {
            let priority = u16::from_be_bytes([body[0], body[1]]);
            let weight = u16::from_be_bytes([body[2], body[3]]);
            let port = u16::from_be_bytes([body[4], body[5]]);
            let (target, _) = Name::decode(message, start + 6)?;
            RecordData::Srv {
                priority,
                weight,
                port,
                target,
            }
        }
        rtype::TXT => {
            let mut entries = Vec::new();
            let mut i = 0usize;
            while i < body.len() {
                let l = body[i] as usize;
                if i + 1 + l > body.len() {
                    // A clipped TXT: keep what was readable rather than throw
                    // the record away. The alternative loses the service.
                    break;
                }
                if l > 0 {
                    entries.push(body[i + 1..i + 1 + l].to_vec());
                }
                i += 1 + l;
            }
            RecordData::Txt(entries)
        }
        other => RecordData::Other {
            rtype: other,
            data: body.to_vec(),
        },
    })
}

pub(crate) fn encode_record(record: &Record, out: &mut Vec<u8>) {
    record.encode(out);
}

/// Splits a TXT record into key/value pairs, the way RFC 6763 §6.3 defines
/// them: everything before the first `=` is the key, everything after is the
/// value, and an entry with no `=` is a key whose value is present-but-empty.
///
/// Non-UTF-8 entries are dropped rather than lossily converted: a caller
/// reading `quic=4433` must not be handed `quic=44\u{fffd}3` and dial it.
pub fn txt_pairs(entries: &[Vec<u8>]) -> Vec<(String, String)> {
    let mut pairs = Vec::new();
    for entry in entries {
        let Ok(text) = std::str::from_utf8(entry) else {
            continue;
        };
        match text.find('=') {
            Some(at) => pairs.push((text[..at].to_string(), text[at + 1..].to_string())),
            None => pairs.push((text.to_string(), String::new())),
        }
    }
    pairs
}

#[cfg(test)]
mod tests {
    use super::*;

    fn n(text: &str) -> Name {
        Name::parse(text).expect("test name parses")
    }

    #[test]
    fn an_srv_record_survives_a_round_trip_including_its_port() {
        let record = Record::flushing(
            n("till-3._telepos._tcp.local"),
            120,
            RecordData::Srv {
                priority: 0,
                weight: 0,
                port: 8443,
                target: n("till-3.local"),
            },
        );
        let mut buffer = Vec::new();
        record.encode(&mut buffer);

        // Skip the name, type, class and ttl to find the rdata.
        let (_, after_name) = Name::decode(&buffer, 0).expect("name");
        let rdlength =
            u16::from_be_bytes([buffer[after_name + 8], buffer[after_name + 9]]) as usize;
        let data = decode_data(&buffer, rtype::SRV, after_name + 10, rdlength).expect("rdata");
        assert_eq!(data, record.data);
    }

    #[test]
    fn the_length_written_is_the_length_of_what_was_written() {
        // The two reserved bytes are filled in after the fact, and getting that
        // wrong produces a record every resolver silently drops.
        let record = Record::flushing(n("till-3.local"), 120, RecordData::A([10, 0, 0, 7].into()));
        let mut buffer = Vec::new();
        record.encode(&mut buffer);
        let (_, after_name) = Name::decode(&buffer, 0).expect("name");
        let rdlength = u16::from_be_bytes([buffer[after_name + 8], buffer[after_name + 9]]);
        assert_eq!(rdlength, 4);
        assert_eq!(buffer.len(), after_name + 10 + 4);
    }

    #[test]
    fn an_empty_txt_is_one_empty_string_and_not_zero_bytes() {
        // RFC 6763 §6.1. Zero-length rdata is illegal and gets the whole record
        // dropped by some resolvers, which loses the service, not the TXT.
        let mut buffer = Vec::new();
        RecordData::Txt(Vec::new()).encode(&mut buffer);
        assert_eq!(buffer, vec![0u8]);
    }

    #[test]
    fn txt_pairs_split_on_the_first_equals_only() {
        let entries = vec![
            b"quic=4433".to_vec(),
            b"path=/rk?a=b".to_vec(),
            b"flag".to_vec(),
        ];
        assert_eq!(
            txt_pairs(&entries),
            vec![
                ("quic".to_string(), "4433".to_string()),
                ("path".to_string(), "/rk?a=b".to_string()),
                ("flag".to_string(), String::new()),
            ]
        );
    }

    #[test]
    fn a_non_utf8_txt_entry_is_dropped_rather_than_mangled() {
        let entries = vec![vec![0xff, 0xfe], b"quic=4433".to_vec()];
        assert_eq!(
            txt_pairs(&entries),
            vec![("quic".to_string(), "4433".to_string())]
        );
    }

    #[test]
    fn a_goodbye_keeps_everything_but_the_lifetime() {
        let record = Record::flushing(n("till-3.local"), 120, RecordData::A([10, 0, 0, 7].into()));
        let goodbye = record.as_goodbye();
        assert_eq!(goodbye.ttl, 0);
        assert!(goodbye.same_answer(&record));
    }

    #[test]
    fn same_answer_ignores_the_remaining_lifetime() {
        // What known-answer suppression compares. A record with 3000 seconds
        // left is the same answer as the one with 4500 that produced it.
        let a = Record::shared(
            n("_telepos._tcp.local"),
            4500,
            RecordData::Ptr(n("till-3._telepos._tcp.local")),
        );
        let mut b = a.clone();
        b.ttl = 3000;
        assert!(a.same_answer(&b));
    }

    #[test]
    fn an_unknown_type_is_kept_whole_rather_than_dropped() {
        let message = [0x01, 0x02, 0x03];
        let data = decode_data(&message, 99, 0, 3).expect("kept");
        assert_eq!(
            data,
            RecordData::Other {
                rtype: 99,
                data: vec![1, 2, 3]
            }
        );
    }

    #[test]
    fn a_clipped_rdata_is_an_error_and_not_a_panic() {
        assert_eq!(
            decode_data(&[0u8; 2], rtype::A, 0, 4),
            Err(NameError::Truncated)
        );
    }
}
