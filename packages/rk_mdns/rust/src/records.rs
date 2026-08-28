//! The record set a responder owns, and what it answers with.
//!
//! Everything here is pure: names in, records out, no socket and no clock. It
//! is the half of the responder that can be checked byte for byte, and the
//! half that a resolver on another machine actually sees.

use std::cmp::Ordering;
use std::net::IpAddr;

use crate::name::Name;
use crate::record::{rtype, Question, Record, RecordData};

/// The DNS-SD service-enumeration name (RFC 6763 §9).
///
/// `avahi-browse -a` and `dns-sd -B _services._dns-sd._udp` ask for this and
/// nothing else. A responder that does not answer it is invisible to the
/// commonest way of looking around a network, which is exactly the tool
/// somebody reaches for when a till cannot be found.
pub const SERVICE_ENUMERATION: &str = "_services._dns-sd._udp.local";

/// One service, one host, and the records that describe them.
#[derive(Debug, Clone)]
pub struct ServiceRecords {
    /// `till-3._telepos._tcp.local`.
    pub instance: Name,
    /// `_telepos._tcp.local`.
    pub service_type: Name,
    /// `till-3.local`.
    pub host: Name,
    /// The port in the `SRV`.
    pub port: u16,
    /// The `TXT` strings, in the order they were given.
    pub txt: Vec<Vec<u8>>,
    /// What the `A` and `AAAA` records carry.
    pub addresses: Vec<IpAddr>,
    /// Seconds for the records that change when the machine moves.
    pub host_ttl: u32,
    /// Seconds for the records that say the service exists at all.
    pub service_ttl: u32,
}

impl ServiceRecords {
    /// The `PTR` from the service type to this instance.
    ///
    /// Shared, not flushing: several tills answer this name, and the
    /// cache-flush bit would make each announcement erase the others out of
    /// every browser on the segment.
    pub fn ptr(&self) -> Record {
        Record::shared(
            self.service_type.clone(),
            self.service_ttl,
            RecordData::Ptr(self.instance.clone()),
        )
    }

    /// The `PTR` that puts this service type in the network's list of types
    /// (RFC 6763 §9). Shared for the same reason.
    pub fn enumeration_ptr(&self) -> Record {
        Record::shared(
            Name::parse(SERVICE_ENUMERATION).expect("a literal that parses"),
            self.service_ttl,
            RecordData::Ptr(self.service_type.clone()),
        )
    }

    /// Host and port.
    pub fn srv(&self) -> Record {
        Record::flushing(
            self.instance.clone(),
            self.host_ttl,
            RecordData::Srv {
                priority: 0,
                weight: 0,
                port: self.port,
                target: self.host.clone(),
            },
        )
    }

    /// The key/value pairs.
    pub fn txt_record(&self) -> Record {
        Record::flushing(
            self.instance.clone(),
            self.service_ttl,
            RecordData::Txt(self.txt.clone()),
        )
    }

    /// One record per address.
    pub fn address_records(&self) -> Vec<Record> {
        self.addresses
            .iter()
            .map(|address| {
                let data = match address {
                    IpAddr::V4(v4) => RecordData::A(*v4),
                    IpAddr::V6(v6) => RecordData::Aaaa(*v6),
                };
                Record::flushing(self.host.clone(), self.host_ttl, data)
            })
            .collect()
    }

    /// Everything, which is what an unsolicited announcement carries.
    pub fn announcement(&self) -> Vec<Record> {
        let mut all = vec![
            self.enumeration_ptr(),
            self.ptr(),
            self.srv(),
            self.txt_record(),
        ];
        all.extend(self.address_records());
        all
    }

    /// The same records with every lifetime at zero — "forget this host"
    /// (RFC 6762 §10.1).
    ///
    /// Sent before the socket closes, and best-effort by nature: a till that
    /// lost power sends nothing, which is why the lifetimes above are minutes
    /// rather than the hour DNS-SD suggests.
    pub fn goodbye(&self) -> Vec<Record> {
        self.announcement().iter().map(Record::as_goodbye).collect()
    }

    /// The records a probe claims (RFC 6762 §8.2), which are the ones a
    /// conflict would be about: this host's unique names, not the shared `PTR`.
    pub fn claimed(&self) -> Vec<Record> {
        let mut claimed = vec![self.srv(), self.txt_record()];
        claimed.extend(self.address_records());
        claimed
    }

    /// The names this responder is authoritative for.
    pub fn owned_names(&self) -> Vec<Name> {
        vec![self.instance.clone(), self.host.clone()]
    }

    /// What to answer one question with: the answers, then the additional
    /// records that save the querier a second round trip.
    ///
    /// `known` is the querier's known-answer list (RFC 6762 §7.1). An answer
    /// it already holds is left out — otherwise every browser refresh makes
    /// every responder on the segment shout, which is what the suppression is
    /// for.
    ///
    /// An empty result means "this question is not about us", and the
    /// responder's reply to that is silence. Answering other people's
    /// questions would make this host the network's problem rather than its
    /// own.
    pub fn answer(&self, question: &Question, known: &[Record]) -> Answer {
        let wants = |t: u16| question.qtype == t || question.qtype == rtype::ANY;

        let mut answers: Vec<Record> = Vec::new();
        let mut additional: Vec<Record> = Vec::new();

        if question.name.eq_ignore_case(&self.service_type) && wants(rtype::PTR) {
            answers.push(self.ptr());
            // RFC 6763 §12: the SRV, TXT and addresses ride along, because a
            // browser that got only the PTR has to ask three more questions
            // before it can connect.
            additional.push(self.srv());
            additional.push(self.txt_record());
            additional.extend(self.address_records());
        } else if question
            .name
            .eq_ignore_case(&Name::parse(SERVICE_ENUMERATION).expect("a literal that parses"))
            && wants(rtype::PTR)
        {
            answers.push(self.enumeration_ptr());
        } else if question.name.eq_ignore_case(&self.instance) {
            if wants(rtype::SRV) {
                answers.push(self.srv());
            }
            if wants(rtype::TXT) {
                answers.push(self.txt_record());
            }
            if !answers.is_empty() {
                additional.extend(self.address_records());
            }
        } else if question.name.eq_ignore_case(&self.host)
            && (wants(rtype::A) || wants(rtype::AAAA))
        {
            for record in self.address_records() {
                // An `A` question is not answered with an `AAAA` record and
                // the other way round: putting a v4 address where a resolver
                // expects a v6 one gives it a connection that goes nowhere.
                if question.qtype == rtype::ANY || record.data.rtype() == question.qtype {
                    answers.push(record);
                }
            }
        }

        // Known-answer suppression applies to the answer section only. An
        // additional record the querier already holds costs nothing and saves
        // the case where its cache entry is about to expire.
        answers.retain(|candidate| {
            !known
                .iter()
                .any(|held| held.same_answer(candidate) && held.ttl * 2 >= candidate.ttl)
        });

        if answers.is_empty() {
            additional.clear();
        }

        Answer {
            answers,
            additional,
        }
    }

    /// The same records under a different instance name, after a conflict.
    ///
    /// The host name moves with it. Two tills that both answer `till-3.local`
    /// is the failure this rename exists to prevent, and renaming only the
    /// service instance would leave the host name contested.
    pub fn renamed(&self, instance_label: &[u8], host_label: &[u8]) -> ServiceRecords {
        ServiceRecords {
            instance: self.service_type.prepend(instance_label),
            host: self.host.without_first_label().prepend(host_label),
            ..self.clone()
        }
    }
}

/// What goes back for one question.
#[derive(Debug, Clone, Default)]
pub struct Answer {
    /// The answer section.
    pub answers: Vec<Record>,
    /// The additional section — everything the querier would have asked next.
    pub additional: Vec<Record>,
}

impl Answer {
    /// Whether this question was about us at all.
    pub fn is_empty(&self) -> bool {
        self.answers.is_empty()
    }
}

/// The label for the `attempt`-th try at a name: the original for the first,
/// then `<original>-2`, `<original>-3`, and so on.
///
/// **The counter is carried by the caller, not read back out of the label.**
/// That is the whole point of this signature. Reading it back cannot work: a
/// till called `till-3` ends in a number the operator chose, and a rename that
/// parsed it would produce `till-4` — the name of the till at the next
/// counter. The first version of this function tried to tell the two apart by
/// looking for a second hyphen, and it got `kassa-2` wrong, which is how the
/// ambiguity was found. There is no rule that separates "a name ending in a
/// number" from "a name with a conflict counter", so the counter is kept
/// where it is known.
///
/// The shape is `-2` rather than RFC 6762 §9's suggested ` (2)`: the label
/// becomes part of `till-3-2.local`, and a host name with a space and brackets
/// in it is legal, unreadable, and a nuisance to type into a browser on a
/// tablet.
pub fn label_for_attempt(original: &[u8], attempt: u32) -> Vec<u8> {
    if attempt <= 1 {
        return original.to_vec();
    }
    let mut label = original.to_vec();
    label.extend_from_slice(format!("-{attempt}").as_bytes());
    label
}

/// Compares two sets of proposed records the way RFC 6762 §8.2 requires, so
/// that two hosts probing for the same name at the same time reach the same
/// verdict about which of them wins.
///
/// Without this the two either both back off — and the name goes unclaimed —
/// or both proceed, and the network holds two hosts answering one name, which
/// is the failure the probe exists to prevent.
pub fn tie_break(ours: &[Record], theirs: &[Record]) -> Ordering {
    let mut a: Vec<Vec<u8>> = ours.iter().map(sortable).collect();
    let mut b: Vec<Vec<u8>> = theirs.iter().map(sortable).collect();
    a.sort();
    b.sort();
    for (x, y) in a.iter().zip(b.iter()) {
        match x.cmp(y) {
            Ordering::Equal => continue,
            other => return other,
        }
    }
    a.len().cmp(&b.len())
}

/// One record flattened to the bytes §8.2 compares: class, then type, then
/// rdata.
fn sortable(record: &Record) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&record.class.to_be_bytes());
    out.extend_from_slice(&record.data.rtype().to_be_bytes());
    let mut rdata = Vec::new();
    // Encoding the whole record and slicing the rdata back out would be
    // fragile; a record with only its data written is exactly what §8.2 wants.
    let holder = Record {
        name: Name::default(),
        ..record.clone()
    };
    crate::record::encode_record(&holder, &mut rdata);
    // Skip the empty name (1 byte), type (2), class (2), ttl (4), rdlength (2).
    out.extend_from_slice(&rdata[11..]);
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::record::CLASS_IN;

    fn n(text: &str) -> Name {
        Name::parse(text).expect("test name parses")
    }

    fn records() -> ServiceRecords {
        ServiceRecords {
            instance: n("till-3._telepos._tcp.local"),
            service_type: n("_telepos._tcp.local"),
            host: n("till-3.local"),
            port: 8443,
            txt: vec![b"quic=4433".to_vec(), b"path=/rk".to_vec()],
            addresses: vec![IpAddr::V4([10, 0, 0, 7].into())],
            host_ttl: 120,
            service_ttl: 4500,
        }
    }

    fn question(name: &str, qtype: u16) -> Question {
        Question {
            name: n(name),
            qtype,
            qclass: CLASS_IN,
            unicast_response: false,
        }
    }

    #[test]
    fn a_service_query_is_answered_with_the_ptr_and_everything_behind_it() {
        // RFC 6763 §12. A browser that got only the PTR has to ask three more
        // questions before it can connect, and on a shop's Wi-Fi that is three
        // more chances to lose a datagram.
        let answer = records().answer(&question("_telepos._tcp.local", rtype::PTR), &[]);
        assert_eq!(answer.answers.len(), 1);
        assert_eq!(answer.answers[0].data.rtype(), rtype::PTR);
        let extra: Vec<u16> = answer.additional.iter().map(|r| r.data.rtype()).collect();
        assert!(extra.contains(&rtype::SRV));
        assert!(extra.contains(&rtype::TXT));
        assert!(extra.contains(&rtype::A));
    }

    #[test]
    fn a_question_about_the_instance_is_answered_without_the_ptr() {
        let answer = records().answer(&question("till-3._telepos._tcp.local", rtype::SRV), &[]);
        assert_eq!(answer.answers.len(), 1);
        assert_eq!(answer.answers[0].data.rtype(), rtype::SRV);
        assert!(answer.additional.iter().any(|r| r.data.rtype() == rtype::A));
    }

    #[test]
    fn a_question_about_the_host_is_answered_with_addresses_only() {
        let answer = records().answer(&question("till-3.local", rtype::A), &[]);
        assert_eq!(answer.answers.len(), 1);
        assert_eq!(answer.answers[0].data.rtype(), rtype::A);
        assert!(answer.additional.is_empty());
    }

    #[test]
    fn an_aaaa_question_is_not_answered_with_an_a_record() {
        // Two records, one question type. Answering an AAAA question with an A
        // record puts a v4 address where a resolver expects a v6 one, and the
        // connection it opens goes nowhere.
        let mut with_v6 = records();
        with_v6
            .addresses
            .push(IpAddr::V6("fe80::1".parse().unwrap()));
        let answer = with_v6.answer(&question("till-3.local", rtype::AAAA), &[]);
        assert_eq!(answer.answers.len(), 1);
        assert_eq!(answer.answers[0].data.rtype(), rtype::AAAA);
    }

    #[test]
    fn any_about_the_host_brings_both_families() {
        let mut with_v6 = records();
        with_v6
            .addresses
            .push(IpAddr::V6("fe80::1".parse().unwrap()));
        let answer = with_v6.answer(&question("till-3.local", rtype::ANY), &[]);
        assert_eq!(answer.answers.len(), 2);
    }

    #[test]
    fn a_question_about_somebody_else_is_answered_with_silence() {
        let answer = records().answer(&question("till-9.local", rtype::A), &[]);
        assert!(answer.is_empty());
        assert!(answer.additional.is_empty());
    }

    #[test]
    fn the_service_enumeration_name_is_answered() {
        // What `avahi-browse -a` asks. A responder that ignores it is invisible
        // to the commonest way of looking around a network.
        let answer = records().answer(&question(SERVICE_ENUMERATION, rtype::PTR), &[]);
        assert_eq!(answer.answers.len(), 1);
        match &answer.answers[0].data {
            RecordData::Ptr(target) => assert!(target.eq_ignore_case(&n("_telepos._tcp.local"))),
            other => panic!("expected a PTR, got {other:?}"),
        }
    }

    #[test]
    fn a_known_answer_is_suppressed() {
        // RFC 6762 §7.1. Without this every browser refresh makes every
        // responder on the segment shout.
        let set = records();
        let known = set.ptr();
        let answer = set.answer(&question("_telepos._tcp.local", rtype::PTR), &[known]);
        assert!(
            answer.is_empty(),
            "the querier said it already holds this and got it again"
        );
    }

    #[test]
    fn a_known_answer_about_to_expire_is_not_suppressed() {
        // §7.1 again: suppression applies only while the querier's copy has
        // more than half its life left. Otherwise a browser's record expires
        // and the service vanishes from a list that was being refreshed the
        // whole time.
        let set = records();
        let mut stale = set.ptr();
        stale.ttl = 100; // against a service TTL of 4500
        let answer = set.answer(&question("_telepos._tcp.local", rtype::PTR), &[stale]);
        assert!(!answer.is_empty());
    }

    #[test]
    fn a_goodbye_is_the_same_records_with_no_lifetime() {
        let set = records();
        let goodbye = set.goodbye();
        assert_eq!(goodbye.len(), set.announcement().len());
        assert!(goodbye.iter().all(|r| r.ttl == 0));
    }

    #[test]
    fn the_ptr_is_shared_and_the_rest_flush() {
        let set = records();
        assert!(!set.ptr().cache_flush, "the shared PTR must not flush");
        assert!(!set.enumeration_ptr().cache_flush);
        assert!(set.srv().cache_flush);
        assert!(set.txt_record().cache_flush);
        assert!(set.address_records().iter().all(|r| r.cache_flush));
    }

    #[test]
    fn a_rename_moves_the_host_name_too() {
        // Renaming only the service instance would leave two tills answering
        // one host name, which is the collision the probe exists to prevent.
        let renamed = records().renamed(b"till-3-2", b"till-3-2");
        assert_eq!(renamed.instance.to_string(), "till-3-2._telepos._tcp.local");
        assert_eq!(renamed.host.to_string(), "till-3-2.local");
        match renamed.srv().data {
            RecordData::Srv { target, .. } => assert_eq!(target.to_string(), "till-3-2.local"),
            other => panic!("expected an SRV, got {other:?}"),
        }
    }

    #[test]
    fn the_counter_comes_from_the_caller_and_never_from_the_label() {
        // The first attempt is the name as given, and every later one appends.
        assert_eq!(label_for_attempt(b"till-3", 1), b"till-3".to_vec());
        assert_eq!(label_for_attempt(b"till-3", 2), b"till-3-2".to_vec());
        assert_eq!(label_for_attempt(b"till-3", 10), b"till-3-10".to_vec());

        // The case that broke the first version of this: a name the operator
        // chose that already ends in `-2`. Parsing it back would produce
        // `kassa-3`, which is a *different till's* name.
        assert_eq!(label_for_attempt(b"kassa-2", 2), b"kassa-2-2".to_vec());
        assert_eq!(label_for_attempt(b"kassa-2", 3), b"kassa-2-3".to_vec());

        // And renaming is never applied twice to its own output: attempt 3
        // starts from the original, not from attempt 2's result.
        let second = label_for_attempt(b"till-3", 2);
        let third = label_for_attempt(b"till-3", 3);
        assert_ne!(label_for_attempt(&second, 2), third);
        assert_eq!(third, b"till-3-3".to_vec());
    }

    #[test]
    fn tie_break_is_decisive_and_agrees_with_itself_from_both_sides() {
        // Both hosts run this on the same two record sets and must reach
        // opposite verdicts. If it ever returned Equal for different sets, both
        // would proceed and the network would hold two hosts on one name.
        let mine = records();
        let mut theirs = records();
        theirs.addresses = vec![IpAddr::V4([10, 0, 0, 9].into())];

        let a = tie_break(&mine.claimed(), &theirs.claimed());
        let b = tie_break(&theirs.claimed(), &mine.claimed());
        assert_ne!(a, Ordering::Equal);
        assert_eq!(a, b.reverse());
    }

    #[test]
    fn tie_break_calls_identical_sets_equal() {
        let set = records();
        assert_eq!(tie_break(&set.claimed(), &set.claimed()), Ordering::Equal);
    }
}
