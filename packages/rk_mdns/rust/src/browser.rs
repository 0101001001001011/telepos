//! The asking half: browsing a service type, and resolving a `.local` name.
//!
//! Dart already has a resolver — `multicast_dns` — so this half is not the
//! reason the package exists. It is here because the two halves share a
//! socket, a cache and a parser, and because a browser written against the
//! same code that answers is the cheapest way to find out that the answering
//! is wrong. The proof that matters is still the other direction: Avahi
//! browsing us, and us browsing Avahi.
//!
//! What it does:
//!
//! - Asks `PTR` for the service type, repeating with the doubling interval of
//!   RFC 6762 §5.2 rather than at a fixed rate, so an idle browser costs the
//!   segment almost nothing.
//! - Sends its cache as known answers (§7.1), so responders stay quiet about
//!   what it already holds.
//! - Follows each `PTR` to `SRV`, `TXT` and addresses, and reports a service
//!   as resolved only when there is enough to connect with — a name, a port
//!   and at least one address.
//! - Reports a service as gone when its records expire or a goodbye arrives,
//!   which is the half a stream of answers cannot give.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::atomic::{AtomicBool, Ordering as AtomicOrdering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};

use crate::cache::Cache;
use crate::interfaces::InterfaceFilter;
use crate::message::Message;
use crate::name::Name;
use crate::record::{rtype, txt_pairs, Question, Record, RecordData, CLASS_IN};
use crate::responder::StartError;
use crate::socket::{SocketOptions, SocketSet, MDNS_PORT};

/// RFC 6762 §5.2: the first query, then one a second later, then doubling.
const FIRST_INTERVAL: Duration = Duration::from_secs(1);
/// The ceiling the doubling stops at — an hour is what §5.2 suggests, and a
/// minute is what a shop floor needs: a till that appears must be found in
/// under a minute, not in under an hour.
const MAX_INTERVAL: Duration = Duration::from_secs(60);

/// How a browser is asked to exist.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct BrowserConfig {
    /// The DNS-SD type to browse — `_telepos._tcp.local`.
    pub service_type: String,
    /// The UDP port. 5353 in use; a private number in tests.
    #[serde(default = "default_mdns_port")]
    pub mdns_port: u16,
    /// Whether to use IPv6.
    #[serde(default = "yes")]
    pub ipv6: bool,
    /// Whether to listen on the loopback interface as well.
    #[serde(default)]
    pub loopback_interface: bool,
    /// If non-empty, only interfaces with these names are used. See
    /// [`crate::responder::ResponderConfig::interfaces`] for why the choice is
    /// the caller's.
    #[serde(default)]
    pub interfaces: Vec<String>,
    /// Interfaces with these names are left out.
    #[serde(default)]
    pub exclude_interfaces: Vec<String>,
    /// Whether this host receives its own multicast.
    #[serde(default = "yes")]
    pub multicast_loopback: bool,
}

/// How a one-shot host resolution is asked for.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct ResolveConfig {
    /// The name — `till-3.local`.
    pub host_name: String,
    /// How long to wait before giving up.
    #[serde(default = "default_resolve_timeout")]
    pub timeout_ms: u64,
    /// The UDP port.
    #[serde(default = "default_mdns_port")]
    pub mdns_port: u16,
    /// Whether to use IPv6.
    #[serde(default = "yes")]
    pub ipv6: bool,
    /// Whether to use the loopback interface as well.
    #[serde(default)]
    pub loopback_interface: bool,
    /// If non-empty, only interfaces with these names are used.
    #[serde(default)]
    pub interfaces: Vec<String>,
    /// Interfaces with these names are left out.
    #[serde(default)]
    pub exclude_interfaces: Vec<String>,
    /// Whether this host receives its own multicast.
    #[serde(default = "yes")]
    pub multicast_loopback: bool,
}

fn default_mdns_port() -> u16 {
    MDNS_PORT
}
fn default_resolve_timeout() -> u64 {
    3000
}
fn yes() -> bool {
    true
}

/// One `key=value` out of a `TXT` record.
#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct TxtPair {
    /// Everything before the first `=`.
    pub key: String,
    /// Everything after it. Empty for an entry with no `=` at all, which
    /// RFC 6763 §6.4 defines as a key that is present with no value.
    pub value: String,
}

/// What the browser reports.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum BrowserEvent {
    /// A service instance exists. Its details may not be known yet.
    ServiceFound {
        /// `till-3._telepos._tcp.local`.
        instance: String,
    },
    /// Enough is known to connect: a host, a port and an address.
    ServiceResolved {
        /// `till-3._telepos._tcp.local`.
        instance: String,
        /// The host name out of the `SRV`.
        host: String,
        /// The port out of the `SRV`.
        port: u16,
        /// What the `A` and `AAAA` records carry.
        addresses: Vec<String>,
        /// The `TXT` record, split.
        txt: Vec<TxtPair>,
    },
    /// The instance is gone — a goodbye arrived, or its records expired.
    ServiceLost {
        /// `till-3._telepos._tcp.local`.
        instance: String,
    },
    /// A query went out.
    Queried {
        /// How many interfaces carried it.
        carried: usize,
        /// How many were offered it.
        interfaces: usize,
    },
    /// Something went wrong the caller is entitled to know about.
    Error {
        /// One line.
        detail: String,
    },
}

/// What a one-shot resolution found.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Resolved {
    /// The name asked about.
    pub host: String,
    /// What answered, in the order the records arrived.
    pub addresses: Vec<String>,
}

/// A running browser.
///
/// Behind locks for the same reason [`crate::responder::Responder`] is: the
/// FFI layer polls from one thread and stops from another.
pub struct Browser {
    events: Mutex<mpsc::Receiver<BrowserEvent>>,
    stop: Arc<AtomicBool>,
    thread: Mutex<Option<JoinHandle<()>>>,
}

impl Browser {
    /// Opens the sockets on the caller's thread, then browses on its own.
    pub fn start(config: BrowserConfig) -> Result<Browser, StartError> {
        let service_type = Name::parse(&config.service_type).map_err(|e| {
            StartError::InvalidArgument(format!("service type '{}': {e}", config.service_type))
        })?;
        if service_type.labels().len() < 3 {
            return Err(StartError::InvalidArgument(format!(
                "service type '{}' is not a DNS-SD type — it wants the shape _name._tcp.local",
                config.service_type
            )));
        }

        let sockets = SocketSet::open(SocketOptions {
            port: config.mdns_port,
            filter: InterfaceFilter {
                loopback: config.loopback_interface,
                ipv6: config.ipv6,
                ipv4: true,
                only: config.interfaces.clone(),
                except: config.exclude_interfaces.clone(),
            },
            loopback: config.multicast_loopback,
        })
        .map_err(StartError::Socket)?;

        let (sender, events) = mpsc::channel();
        let stop = Arc::new(AtomicBool::new(false));
        let thread = {
            let stop = Arc::clone(&stop);
            std::thread::Builder::new()
                .name("rk_mdns browser".into())
                .spawn(move || {
                    let mut engine = BrowseEngine {
                        sockets,
                        service_type,
                        cache: Cache::new(),
                        known: HashMap::new(),
                        events: sender,
                        stop,
                    };
                    engine.run();
                })
                .map_err(|e| StartError::InvalidArgument(format!("no thread: {e}")))?
        };

        Ok(Browser {
            events: Mutex::new(events),
            stop,
            thread: Mutex::new(Some(thread)),
        })
    }

    /// The next event, or `None` when the wait expired.
    pub fn poll(&self, timeout: Duration) -> Option<BrowserEvent> {
        let events = self.events.lock().ok()?;
        events.recv_timeout(timeout).ok()
    }

    /// Stops browsing. Stopping twice is not an error.
    pub fn stop(&self) {
        self.stop.store(true, AtomicOrdering::SeqCst);
        let thread = self.thread.lock().ok().and_then(|mut slot| slot.take());
        if let Some(thread) = thread {
            let _ = thread.join();
        }
    }

    /// Whether the browser's thread is still running.
    pub fn is_running(&self) -> bool {
        !self.stop.load(AtomicOrdering::SeqCst)
    }
}

impl Drop for Browser {
    fn drop(&mut self) {
        self.stop();
    }
}

/// Asks for one `.local` name and waits for an answer.
///
/// Blocking on purpose, and bounded by `timeout_ms`. A caller that wants this
/// off its own thread has one; a caller that wants an address before it can do
/// anything at all should not have to build a state machine for it.
pub fn resolve_host(config: ResolveConfig) -> Result<Resolved, StartError> {
    let host = Name::parse(&config.host_name)
        .map_err(|e| StartError::InvalidArgument(format!("host name: {e}")))?;
    if host.is_root() {
        return Err(StartError::InvalidArgument("the host name is empty".into()));
    }

    let mut sockets = SocketSet::open(SocketOptions {
        port: config.mdns_port,
        filter: InterfaceFilter {
            loopback: config.loopback_interface,
            ipv6: config.ipv6,
            ipv4: true,
            only: config.interfaces.clone(),
            except: config.exclude_interfaces.clone(),
        },
        loopback: config.multicast_loopback,
    })
    .map_err(StartError::Socket)?;

    let query = Message::query(
        vec![
            Question {
                name: host.clone(),
                qtype: rtype::A,
                qclass: CLASS_IN,
                unicast_response: false,
            },
            Question {
                name: host.clone(),
                qtype: rtype::AAAA,
                qclass: CLASS_IN,
                unicast_response: false,
            },
        ],
        Vec::new(),
    )
    .encode();

    let deadline = Instant::now() + Duration::from_millis(config.timeout_ms);
    let mut addresses: Vec<String> = Vec::new();
    let mut next_query = Instant::now();

    while Instant::now() < deadline {
        if Instant::now() >= next_query {
            sockets.send_to_group(&query);
            // Repeat once a second: a single unacknowledged datagram on a
            // wireless segment is not a question, it is a hope.
            next_query = Instant::now() + Duration::from_secs(1);
        }
        let Some(received) = sockets.recv(Duration::from_millis(100)) else {
            continue;
        };
        let Ok(message) = Message::decode(&received.payload) else {
            continue;
        };
        if !message.is_response() {
            continue;
        }
        for record in message.answers.iter().chain(message.additional.iter()) {
            if !record.name.eq_ignore_case(&host) || record.ttl == 0 {
                continue;
            }
            let found = match &record.data {
                RecordData::A(v4) => Some(IpAddr::V4(*v4).to_string()),
                RecordData::Aaaa(v6) => Some(IpAddr::V6(*v6).to_string()),
                _ => None,
            };
            if let Some(address) = found {
                if !addresses.contains(&address) {
                    addresses.push(address);
                }
            }
        }
        if !addresses.is_empty() {
            // Wait a further short moment for the second family rather than
            // returning the first record that lands: a host with a v4 and a v6
            // address sends both, and returning after the first makes which one
            // a caller gets depend on packet order.
            let settle = Instant::now() + Duration::from_millis(150);
            while Instant::now() < settle {
                let Some(more) = sockets.recv(Duration::from_millis(50)) else {
                    continue;
                };
                let Ok(message) = Message::decode(&more.payload) else {
                    continue;
                };
                for record in message.answers.iter().chain(message.additional.iter()) {
                    if !record.name.eq_ignore_case(&host) || record.ttl == 0 {
                        continue;
                    }
                    let found = match &record.data {
                        RecordData::A(v4) => Some(IpAddr::V4(*v4).to_string()),
                        RecordData::Aaaa(v6) => Some(IpAddr::V6(*v6).to_string()),
                        _ => None,
                    };
                    if let Some(address) = found {
                        if !addresses.contains(&address) {
                            addresses.push(address);
                        }
                    }
                }
            }
            break;
        }
    }

    Ok(Resolved {
        host: host.to_string(),
        addresses,
    })
}

/// What has already been said about one instance, so it is not said twice.
#[derive(Default)]
struct Reported {
    found: bool,
    resolved: Option<String>,
}

struct BrowseEngine {
    sockets: SocketSet,
    service_type: Name,
    cache: Cache,
    known: HashMap<String, Reported>,
    events: mpsc::Sender<BrowserEvent>,
    stop: Arc<AtomicBool>,
}

impl BrowseEngine {
    fn run(&mut self) {
        let mut interval = FIRST_INTERVAL;
        let mut next_query = Instant::now();

        while !self.stop.load(AtomicOrdering::SeqCst) {
            let now = Instant::now();
            if now >= next_query {
                self.query();
                next_query = now + interval;
                // §5.2: double, up to the ceiling. A browser left open on a
                // shop floor must not cost the segment a query a second for
                // the rest of the day.
                interval = (interval * 2).min(MAX_INTERVAL);
            }

            if let Some(received) = self.sockets.recv(Duration::from_millis(100)) {
                self.absorb(&received.payload);
            }

            for gone in self.cache.expire(Instant::now()) {
                self.retire(&gone);
            }
        }
    }

    fn query(&mut self) {
        let now = Instant::now();
        let known = self
            .cache
            .known_answers(&self.service_type, rtype::PTR, now);
        let mut questions = vec![Question {
            name: self.service_type.clone(),
            qtype: rtype::PTR,
            qclass: CLASS_IN,
            unicast_response: false,
        }];
        // Ask about the instances already known too, so an instance whose SRV
        // was lost is repaired without waiting for the responder to announce
        // again.
        for instance in self.instances_needing_detail(now) {
            questions.push(Question {
                name: instance.clone(),
                qtype: rtype::SRV,
                qclass: CLASS_IN,
                unicast_response: false,
            });
            questions.push(Question {
                name: instance,
                qtype: rtype::TXT,
                qclass: CLASS_IN,
                unicast_response: false,
            });
        }
        let payload = Message::query(questions, known).encode();
        let carried = self.sockets.send_to_group(&payload);
        let interfaces = self.sockets.len();
        let _ = self.events.send(BrowserEvent::Queried {
            carried,
            interfaces,
        });
    }

    fn instances_needing_detail(&self, _now: Instant) -> Vec<Name> {
        let mut wanted = Vec::new();
        for record in self.cache.records(&self.service_type, rtype::PTR) {
            let RecordData::Ptr(instance) = &record.data else {
                continue;
            };
            let has_srv = !self.cache.records(instance, rtype::SRV).is_empty();
            let has_txt = !self.cache.records(instance, rtype::TXT).is_empty();
            if !has_srv || !has_txt {
                wanted.push(instance.clone());
            }
        }
        wanted
    }

    fn absorb(&mut self, payload: &[u8]) {
        let Ok(message) = Message::decode(payload) else {
            return;
        };
        if !message.is_response() {
            return;
        }
        let now = Instant::now();
        let mut goodbyes: Vec<Record> = Vec::new();
        for record in message.answers.iter().chain(message.additional.iter()) {
            if record.ttl == 0 {
                goodbyes.push(record.clone());
            }
            self.cache.put(record, now);
        }
        // A goodbye retires the entry rather than deleting it (§10.1), so the
        // instance disappears one second later through the ordinary expiry
        // path. Nothing is reported here; `retire` does it.
        let _ = goodbyes;
        self.report();
    }

    /// Says what is new, and only what is new.
    fn report(&mut self) {
        let instances: Vec<Name> = self
            .cache
            .records(&self.service_type, rtype::PTR)
            .into_iter()
            .filter_map(|record| match &record.data {
                RecordData::Ptr(instance) => Some(instance.clone()),
                _ => None,
            })
            .collect();

        for instance in instances {
            let key = instance.to_string();
            let entry = self.known.entry(key.clone()).or_default();
            if !entry.found {
                entry.found = true;
                let _ = self.events.send(BrowserEvent::ServiceFound {
                    instance: key.clone(),
                });
            }

            let Some(details) = self.details(&instance) else {
                continue;
            };
            // A fingerprint of everything a caller would act on, so a repeated
            // announcement is silent and a changed port is not.
            let fingerprint = format!(
                "{}|{}|{:?}|{:?}",
                details.0, details.1, details.2, details.3
            );
            let entry = self.known.entry(key.clone()).or_default();
            if entry.resolved.as_deref() == Some(fingerprint.as_str()) {
                continue;
            }
            entry.resolved = Some(fingerprint);
            let _ = self.events.send(BrowserEvent::ServiceResolved {
                instance: key,
                host: details.0,
                port: details.1,
                addresses: details.2,
                txt: details.3,
            });
        }
    }

    /// Host, port, addresses and TXT — or `None` while any of them is missing.
    ///
    /// A service is reported as resolved only when there is enough to connect
    /// with. Reporting it earlier puts an entry in an operator's list that
    /// fails at the first tap, which is worse than an entry that is a moment
    /// late.
    #[allow(clippy::type_complexity)]
    fn details(&self, instance: &Name) -> Option<(String, u16, Vec<String>, Vec<TxtPair>)> {
        let srv = self.cache.records(instance, rtype::SRV);
        let (target, port) = srv.iter().find_map(|record| match &record.data {
            RecordData::Srv { port, target, .. } => Some((target.clone(), *port)),
            _ => None,
        })?;

        let mut addresses = Vec::new();
        for record in self.cache.records(&target, rtype::ANY) {
            match &record.data {
                RecordData::A(v4) => addresses.push(IpAddr::V4(*v4).to_string()),
                RecordData::Aaaa(v6) => addresses.push(IpAddr::V6(*v6).to_string()),
                _ => {}
            }
        }
        if addresses.is_empty() {
            return None;
        }
        addresses.sort();

        let txt = self
            .cache
            .records(instance, rtype::TXT)
            .iter()
            .find_map(|record| match &record.data {
                RecordData::Txt(entries) => Some(
                    txt_pairs(entries)
                        .into_iter()
                        .map(|(key, value)| TxtPair { key, value })
                        .collect::<Vec<_>>(),
                ),
                _ => None,
            })
            .unwrap_or_default();

        Some((target.to_string(), port, addresses, txt))
    }

    /// Reports an instance gone when the record that named it expires.
    fn retire(&mut self, gone: &Record) {
        let RecordData::Ptr(instance) = &gone.data else {
            return;
        };
        if !gone.name.eq_ignore_case(&self.service_type) {
            return;
        }
        let key = instance.to_string();
        if self.known.remove(&key).is_some() {
            let _ = self
                .events
                .send(BrowserEvent::ServiceLost { instance: key });
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_browser_config_with_an_unknown_key_is_refused() {
        let json = r#"{"serviceType":"_telepos._tcp.local","mdnsport":5353}"#;
        let parsed: Result<BrowserConfig, _> = serde_json::from_str(json);
        assert!(parsed.is_err());
    }

    #[test]
    fn a_service_type_that_is_not_one_is_refused_before_a_socket_opens() {
        let config = BrowserConfig {
            service_type: "local".into(),
            mdns_port: 1,
            ipv6: false,
            loopback_interface: true,
            interfaces: Vec::new(),
            exclude_interfaces: Vec::new(),
            multicast_loopback: true,
        };
        assert!(matches!(
            Browser::start(config),
            Err(StartError::InvalidArgument(_))
        ));
    }

    #[test]
    fn a_resolve_of_an_empty_name_is_refused() {
        let config = ResolveConfig {
            host_name: String::new(),
            timeout_ms: 10,
            mdns_port: 1,
            ipv6: false,
            loopback_interface: true,
            interfaces: Vec::new(),
            exclude_interfaces: Vec::new(),
            multicast_loopback: true,
        };
        assert!(matches!(
            resolve_host(config),
            Err(StartError::InvalidArgument(_))
        ));
    }

    #[test]
    fn the_query_interval_doubles_to_the_ceiling_and_stops() {
        let mut interval = FIRST_INTERVAL;
        for _ in 0..20 {
            interval = (interval * 2).min(MAX_INTERVAL);
        }
        assert_eq!(interval, MAX_INTERVAL);
    }
}
