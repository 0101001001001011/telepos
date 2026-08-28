//! What a resolver remembers, and for how long.
//!
//! A cache is not an optimisation here — it is what makes "the service went
//! away" a thing that can be said at all. Without one there is only a stream
//! of answers, and a browser cannot tell a service that stopped answering from
//! a datagram that got lost.
//!
//! Pure: records and a clock in, changes out. No socket.

use std::time::{Duration, Instant};

use crate::name::Name;
use crate::record::{rtype, Record};

/// RFC 6762 §10.1: a goodbye does not delete the entry, it sets its remaining
/// lifetime to one second.
///
/// The second is not politeness. A goodbye and the announcement of a *new*
/// address can cross on the wire, and deleting immediately would drop the new
/// one on the floor. One second is long enough for the reordering and short
/// enough that nobody notices.
const GOODBYE_GRACE: Duration = Duration::from_secs(1);

/// What happened to the cache when a record arrived.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Change {
    /// Nothing was held for this name and type.
    Added,
    /// The same answer was already held; its lifetime was extended.
    Refreshed,
    /// A different answer replaced what was held.
    Replaced,
    /// A goodbye put the entry on its last second.
    Retiring,
}

struct Entry {
    record: Record,
    expires: Instant,
}

/// Records held with their lifetimes.
#[derive(Default)]
pub struct Cache {
    entries: Vec<Entry>,
}

impl Cache {
    /// An empty cache.
    pub fn new() -> Cache {
        Cache::default()
    }

    /// How many records are held. For tests and for a diagnostic; nothing
    /// branches on it.
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Whether nothing is held.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Takes a record in, and says what that did.
    pub fn put(&mut self, record: &Record, now: Instant) -> Change {
        if record.ttl == 0 {
            // A goodbye (§10.1).
            let mut change = Change::Retiring;
            let mut found = false;
            for entry in self.entries.iter_mut() {
                if entry.record.same_answer(record) {
                    found = true;
                    let retire_at = now + GOODBYE_GRACE;
                    if retire_at < entry.expires {
                        entry.expires = retire_at;
                    }
                }
            }
            if !found {
                // A goodbye for something never held is not news.
                change = Change::Refreshed;
            }
            return change;
        }

        let expires = now + Duration::from_secs(record.ttl as u64);

        if let Some(entry) = self
            .entries
            .iter_mut()
            .find(|e| e.record.same_answer(record))
        {
            entry.expires = expires;
            entry.record.ttl = record.ttl;
            return Change::Refreshed;
        }

        // The cache-flush bit (§10.2): this sender is authoritative for the
        // name, so what it says replaces what was held for that name and type
        // rather than joining it. Without this a host that changed address is
        // cached at both, and half the connections go where nothing answers.
        //
        // Address records are the exception inside the exception: a host with
        // two interfaces sends two A records in one message, and treating the
        // second as a replacement for the first would leave one address out of
        // every two.
        let mut replaced = false;
        if record.cache_flush && !is_address(record) {
            let before = self.entries.len();
            self.entries.retain(|e| {
                !(e.record.name.eq_ignore_case(&record.name)
                    && e.record.data.rtype() == record.data.rtype())
            });
            replaced = self.entries.len() != before;
        }

        self.entries.push(Entry {
            record: record.clone(),
            expires,
        });

        if replaced {
            Change::Replaced
        } else {
            Change::Added
        }
    }

    /// Drops everything whose lifetime ran out, and hands back what was
    /// dropped so a browser can report the services that went away.
    pub fn expire(&mut self, now: Instant) -> Vec<Record> {
        let mut gone = Vec::new();
        self.entries.retain(|entry| {
            if entry.expires <= now {
                gone.push(entry.record.clone());
                false
            } else {
                true
            }
        });
        gone
    }

    /// Everything held for this name and type.
    pub fn records(&self, name: &Name, want: u16) -> Vec<&Record> {
        self.entries
            .iter()
            .filter(|e| {
                e.record.name.eq_ignore_case(name)
                    && (want == rtype::ANY || e.record.data.rtype() == want)
            })
            .map(|e| &e.record)
            .collect()
    }

    /// The known-answer list for a repeated query (RFC 6762 §7.1), with each
    /// record's **remaining** lifetime rather than its original one.
    ///
    /// The remaining lifetime is the point: a responder suppresses an answer
    /// only while the querier's copy has more than half its life left, and
    /// sending the original TTL would suppress answers the querier is about to
    /// lose.
    pub fn known_answers(&self, name: &Name, want: u16, now: Instant) -> Vec<Record> {
        self.entries
            .iter()
            .filter(|e| {
                e.record.name.eq_ignore_case(name)
                    && (want == rtype::ANY || e.record.data.rtype() == want)
                    && e.expires > now
            })
            .map(|e| {
                let mut record = e.record.clone();
                record.ttl = e.expires.saturating_duration_since(now).as_secs() as u32;
                record
            })
            .collect()
    }
}

fn is_address(record: &Record) -> bool {
    matches!(record.data.rtype(), rtype::A | rtype::AAAA)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::record::RecordData;

    fn n(text: &str) -> Name {
        Name::parse(text).expect("test name parses")
    }

    fn a(address: [u8; 4], ttl: u32) -> Record {
        Record::flushing(n("till-3.local"), ttl, RecordData::A(address.into()))
    }

    #[test]
    fn a_new_record_is_added_and_the_same_one_again_only_refreshes() {
        let mut cache = Cache::new();
        let now = Instant::now();
        assert_eq!(cache.put(&a([10, 0, 0, 7], 120), now), Change::Added);
        assert_eq!(cache.put(&a([10, 0, 0, 7], 120), now), Change::Refreshed);
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn a_record_expires_when_its_lifetime_runs_out() {
        let mut cache = Cache::new();
        let now = Instant::now();
        cache.put(&a([10, 0, 0, 7], 2), now);
        assert!(cache.expire(now + Duration::from_secs(1)).is_empty());
        let gone = cache.expire(now + Duration::from_secs(3));
        assert_eq!(gone.len(), 1);
        assert!(cache.is_empty());
    }

    #[test]
    fn a_goodbye_puts_the_entry_on_its_last_second_rather_than_deleting_it() {
        // RFC 6762 §10.1. A goodbye and the announcement of a NEW address can
        // cross on the wire; deleting at once would drop the new one.
        let mut cache = Cache::new();
        let now = Instant::now();
        cache.put(&a([10, 0, 0, 7], 120), now);
        assert_eq!(cache.put(&a([10, 0, 0, 7], 0), now), Change::Retiring);
        assert_eq!(cache.len(), 1, "the entry was deleted rather than retired");
        assert!(cache.expire(now + Duration::from_millis(500)).is_empty());
        assert_eq!(cache.expire(now + Duration::from_secs(2)).len(), 1);
    }

    #[test]
    fn a_goodbye_for_something_never_held_is_not_news() {
        let mut cache = Cache::new();
        assert_eq!(
            cache.put(&a([10, 0, 0, 7], 0), Instant::now()),
            Change::Refreshed
        );
        assert!(cache.is_empty());
    }

    #[test]
    fn the_cache_flush_bit_replaces_rather_than_accumulates() {
        // A host that changed address must not be cached at both, or half the
        // connections go where nothing answers.
        let mut cache = Cache::new();
        let now = Instant::now();
        let srv = |port: u16| {
            Record::flushing(
                n("till-3._telepos._tcp.local"),
                120,
                RecordData::Srv {
                    priority: 0,
                    weight: 0,
                    port,
                    target: n("till-3.local"),
                },
            )
        };
        assert_eq!(cache.put(&srv(8443), now), Change::Added);
        assert_eq!(cache.put(&srv(9443), now), Change::Replaced);
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn two_addresses_of_one_host_both_survive_the_cache_flush_bit() {
        // The exception that matters: a host with a cable and a Wi-Fi card
        // sends two A records in one message, both with the flush bit. Treating
        // the second as a replacement leaves one address out of every two, and
        // the one that survives is whichever arrived last.
        let mut cache = Cache::new();
        let now = Instant::now();
        cache.put(&a([10, 0, 0, 7], 120), now);
        cache.put(&a([192, 168, 1, 7], 120), now);
        assert_eq!(cache.records(&n("till-3.local"), rtype::A).len(), 2);
    }

    #[test]
    fn known_answers_carry_what_is_left_and_not_what_was_given() {
        // §7.1: a responder suppresses only while the querier's copy has more
        // than half its life left. Sending the original TTL would suppress
        // answers the querier is about to lose.
        let mut cache = Cache::new();
        let now = Instant::now();
        cache.put(&a([10, 0, 0, 7], 120), now);
        let known =
            cache.known_answers(&n("till-3.local"), rtype::A, now + Duration::from_secs(100));
        assert_eq!(known.len(), 1);
        assert!(known[0].ttl <= 20, "ttl was {}", known[0].ttl);
    }

    #[test]
    fn an_expired_record_is_not_offered_as_a_known_answer() {
        let mut cache = Cache::new();
        let now = Instant::now();
        cache.put(&a([10, 0, 0, 7], 5), now);
        let known =
            cache.known_answers(&n("till-3.local"), rtype::A, now + Duration::from_secs(10));
        assert!(known.is_empty());
    }
}
