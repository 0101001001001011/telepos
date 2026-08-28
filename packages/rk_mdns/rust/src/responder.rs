//! The responder: the half of mDNS that no Dart package has.
//!
//! It runs on its own thread and owns one socket per interface. What it does,
//! in the order RFC 6762 puts it:
//!
//! 1. **Probes** (§8.1) — three questions of type `ANY` for the names it means
//!    to claim, 250 ms apart, after a random delay of up to 250 ms. The delay
//!    is not decoration: two tills powered on by the same switch would
//!    otherwise probe in lockstep forever.
//! 2. **Resolves a conflict** (§8.1, §8.2) — if anything answers for those
//!    names, or probes for them at the same time and wins the tie-break, the
//!    instance and the host name both gain a `-2` and probing starts again.
//!    Two tills named alike is a setup mistake, and it has to be **visible**
//!    rather than silent: the caller is told the name it ended up with.
//! 3. **Announces** (§8.3) — at least twice, a second apart, because the first
//!    one is a single unacknowledged datagram on a medium that drops them.
//! 4. **Answers** — the instance and the host separately, with known-answer
//!    suppression (§7.1) and a unicast reply when the `QU` bit asks for one
//!    (§5.4).
//! 5. **Says goodbye** (§10.1) — the same records with a lifetime of zero, so
//!    a tablet does not hold a dead till in its cache for the next two minutes.

use std::net::{IpAddr, SocketAddr};
use std::sync::atomic::{AtomicBool, Ordering as AtomicOrdering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};

use crate::interfaces::InterfaceFilter;
use crate::message::Message;
use crate::name::Name;
use crate::record::{rtype, Question, Record, CLASS_IN};
use crate::records::{label_for_attempt, tie_break, ServiceRecords};
use crate::socket::{SocketError, SocketOptions, SocketSet, MDNS_PORT};

/// RFC 6762 §8.1: three probes.
const PROBE_COUNT: u32 = 3;
/// §8.1: 250 ms between them, and up to 250 ms before the first.
const PROBE_INTERVAL: Duration = Duration::from_millis(250);
/// §8.3: the second announcement one second after the first.
const ANNOUNCE_INTERVAL: Duration = Duration::from_secs(1);
/// §8.3 wants at least two; three costs one datagram and covers a lost one.
const ANNOUNCE_COUNT: u32 = 3;
/// How many renames before the responder gives up and says so.
///
/// A network with twenty `till-3`s on it is not a naming collision, it is a
/// misconfigured deployment, and going round forever would hide that.
const MAX_RENAMES: u32 = 20;

/// How a responder is asked to exist.
///
/// An unknown key is an error rather than something ignored: a typo must not
/// look like a setting that took effect.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct ResponderConfig {
    /// The instance label — `till-3`. Becomes `till-3._telepos._tcp.local`.
    pub instance_name: String,
    /// The DNS-SD service type — `_telepos._tcp.local`.
    pub service_type: String,
    /// The host name to claim. Defaults to `<instance_name>.local`.
    #[serde(default)]
    pub host_name: Option<String>,
    /// The port in the `SRV` record.
    pub port: u16,
    /// `TXT` strings, in order, each usually `key=value`.
    #[serde(default)]
    pub txt: Vec<String>,
    /// What to put in `A` and `AAAA`. Empty means every address of every
    /// interface the sockets came up on.
    #[serde(default)]
    pub addresses: Vec<String>,
    /// If non-empty, only interfaces with these names are used — for sending
    /// and for the addresses announced.
    ///
    /// # Why this is here and why it is not decided for you
    ///
    /// **The cost of a spare address is not symmetric.** In a TLS certificate
    /// an `iPAddress` entry is checked: a spare one costs nothing, a missing
    /// one costs the handshake. In an mDNS announcement an address is *tried*:
    /// a client works down the list, so a spare one costs it a connection
    /// timeout. This side has to be stricter than the certificate.
    ///
    /// Measured 2026-08-06: on the development machine four addresses survive
    /// the ordinary filters, and two of them — a Hyper-V switch and a WSL
    /// switch — are unreachable from any client, one timeout each.
    ///
    /// **Filtering by address cannot separate them.** A prefix rule that threw
    /// out `172.16/12` and `10/8` would throw out the shop networks this is
    /// for. What distinguishes a virtual switch from a cable is the interface,
    /// so the caller names it, and this crate does not guess — the same
    /// decision `rk_pki` took about which addresses belong in a certificate.
    ///
    /// A name that matches no interface is an error naming the ones that
    /// exist, not silence: a typo in a setting must not look like a machine
    /// with no network.
    #[serde(default)]
    pub interfaces: Vec<String>,
    /// Interfaces with these names are left out. Applied after
    /// [`Self::interfaces`].
    #[serde(default)]
    pub exclude_interfaces: Vec<String>,
    /// Seconds for the records that change when the machine moves.
    ///
    /// Two minutes by default, not the hour DNS-SD suggests for a stable
    /// service: a host that moved by DHCP has to become findable at its new
    /// address without anybody power-cycling a tablet, and the goodbye only
    /// covers the stops that are clean.
    #[serde(default = "default_host_ttl")]
    pub host_ttl_seconds: u32,
    /// Seconds for the records that say the service exists at all.
    #[serde(default = "default_service_ttl")]
    pub service_ttl_seconds: u32,
    /// The UDP port. 5353 in use; a private number in tests, so the machine's
    /// own responder does not answer questions meant for this one.
    #[serde(default = "default_mdns_port")]
    pub mdns_port: u16,
    /// Whether to probe before claiming. Off only for a test that wants the
    /// records on the wire immediately.
    #[serde(default = "yes")]
    pub probe: bool,
    /// Whether to use IPv6.
    #[serde(default = "yes")]
    pub ipv6: bool,
    /// Whether to send on the loopback interface as well.
    ///
    /// On for the same-host proof against `avahi-resolve`, which is the only
    /// place the proof can be run on a segment that does not carry multicast.
    #[serde(default)]
    pub loopback_interface: bool,
    /// Whether this host receives its own multicast.
    #[serde(default = "yes")]
    pub multicast_loopback: bool,
}

fn default_host_ttl() -> u32 {
    120
}
fn default_service_ttl() -> u32 {
    4500
}
fn default_mdns_port() -> u16 {
    MDNS_PORT
}
fn yes() -> bool {
    true
}

/// What the responder reports as it happens.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum ResponderEvent {
    /// A probe went out.
    Probing {
        /// The instance name being claimed.
        instance: String,
        /// The host name being claimed.
        host: String,
        /// Which of the three this was, from 1.
        attempt: u32,
    },
    /// Somebody else holds the name, and this responder moved.
    ///
    /// The most important event here. Two tills named alike is a setup mistake
    /// this package *can* detect, and reporting it is the difference between a
    /// visible misconfiguration and a tablet that reaches whichever till
    /// replied first.
    NameConflict {
        /// The name that was contested.
        from: String,
        /// The name taken instead.
        to: String,
        /// Who or what the conflict was with.
        detail: String,
    },
    /// The names are claimed and the records are live.
    Claimed {
        /// The instance name in the end.
        instance: String,
        /// The host name in the end.
        host: String,
        /// What the address records carry.
        addresses: Vec<String>,
        /// How many interfaces the records go out on.
        interfaces: usize,
    },
    /// An announcement went out.
    Announced {
        /// How many interfaces carried it.
        carried: usize,
        /// How many were offered it.
        interfaces: usize,
    },
    /// A question was answered.
    Answered {
        /// What was asked.
        question: String,
        /// Who asked.
        to: String,
        /// Whether the reply went straight back rather than to the group.
        unicast: bool,
        /// How many records went in the answer section.
        answers: usize,
    },
    /// The goodbye went out and the responder is done.
    Goodbye {
        /// How many interfaces carried it.
        carried: usize,
    },
    /// Something went wrong that the caller is entitled to know about.
    Error {
        /// One line.
        detail: String,
    },
}

/// What a live responder ended up with.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ResponderState {
    /// The instance name actually claimed, after any rename.
    pub instance: String,
    /// The host name actually claimed.
    pub host: String,
    /// What the address records carry.
    pub addresses: Vec<String>,
    /// Whether probing has finished.
    pub claimed: bool,
    /// One entry per interface, with what each has carried.
    pub interfaces: Vec<InterfaceReport>,
}

/// What one interface has done.
///
/// Reported rather than kept private because "sent on every interface" is a
/// claim, and a claim needs a number behind it. A test asserts every entry has
/// carried something; that test is what goes red on a return to sending by
/// whatever the routing table prefers.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InterfaceReport {
    /// The operating system's name for it.
    pub name: String,
    /// The address it sends from.
    pub address: String,
    /// The interface index.
    pub index: u32,
    /// Datagrams that left through it.
    pub sent: u64,
    /// Sends it refused.
    pub failed: u64,
}

/// A running responder.
///
/// Every field a caller can reach is behind a lock, and that is what makes a
/// `&Responder` usable from two threads at once — which the FFI layer needs,
/// because a caller polls for events on one thread and stops the responder
/// from another. Holding the whole thing behind one mutex instead would mean a
/// poll with a two-second timeout blocks the stop for two seconds, and the
/// goodbye is the one datagram that must not be late.
pub struct Responder {
    events: Mutex<mpsc::Receiver<ResponderEvent>>,
    stop: Arc<AtomicBool>,
    state: Arc<Mutex<ResponderState>>,
    thread: Mutex<Option<JoinHandle<()>>>,
}

/// Why a responder could not start.
#[derive(Debug)]
pub enum StartError {
    /// A name, an address or a port that cannot be used.
    InvalidArgument(String),
    /// The sockets did not come up.
    Socket(SocketError),
}

impl std::fmt::Display for StartError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            StartError::InvalidArgument(detail) => write!(f, "{detail}"),
            StartError::Socket(error) => write!(f, "{error}"),
        }
    }
}

impl Responder {
    /// Opens the sockets, then hands the rest to a thread.
    ///
    /// The sockets are opened **here**, on the caller's thread, so that a port
    /// that cannot be bound is an error the caller sees rather than an event
    /// it has to poll for. Everything after that — probing, announcing,
    /// answering — happens on the thread.
    pub fn start(config: ResponderConfig) -> Result<Responder, StartError> {
        if config.instance_name.trim().is_empty() {
            return Err(StartError::InvalidArgument(
                "the instance name is empty, and announcing a nameless service would take a \
                 name on the network that resolves to nothing"
                    .into(),
            ));
        }
        if config.port == 0 {
            return Err(StartError::InvalidArgument(
                "port 0 in an SRV record tells a client to connect to nothing".into(),
            ));
        }

        let service_type = Name::parse(&config.service_type).map_err(|e| {
            StartError::InvalidArgument(format!("service type '{}': {e}", config.service_type))
        })?;
        if service_type.labels().len() < 3 {
            return Err(StartError::InvalidArgument(format!(
                "service type '{}' is not a DNS-SD type — it wants the shape \
                 _name._tcp.local",
                config.service_type
            )));
        }
        let instance_label = Name::parse(&config.instance_name)
            .map_err(|e| StartError::InvalidArgument(format!("instance name: {e}")))?;
        if instance_label.labels().len() != 1 {
            return Err(StartError::InvalidArgument(format!(
                "instance name '{}' is one label, not a name — escape a dot as \\.",
                config.instance_name
            )));
        }
        let host_name = match &config.host_name {
            Some(explicit) => Name::parse(explicit)
                .map_err(|e| StartError::InvalidArgument(format!("host name: {e}")))?,
            None => Name::parse(&format!("{}.local", config.instance_name))
                .map_err(|e| StartError::InvalidArgument(format!("host name: {e}")))?,
        };

        let mut explicit_addresses = Vec::new();
        for text in &config.addresses {
            let address: IpAddr = text
                .parse()
                .map_err(|_| StartError::InvalidArgument(format!("'{text}' is not an address")))?;
            explicit_addresses.push(address);
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

        let addresses = if explicit_addresses.is_empty() {
            sockets.advertisable()
        } else {
            explicit_addresses
        };
        if addresses.is_empty() {
            return Err(StartError::InvalidArgument(
                "this machine has no address worth announcing — a service with no A or AAAA \
                 record looks alive in a browser and fails at the first connection"
                    .into(),
            ));
        }

        let records = ServiceRecords {
            instance: service_type.prepend(&instance_label.labels()[0]),
            service_type,
            host: host_name,
            port: config.port,
            txt: config.txt.iter().map(|t| t.as_bytes().to_vec()).collect(),
            addresses,
            host_ttl: config.host_ttl_seconds,
            service_ttl: config.service_ttl_seconds,
        };

        let state = Arc::new(Mutex::new(ResponderState {
            instance: records.instance.to_string(),
            host: records.host.to_string(),
            addresses: records.addresses.iter().map(|a| a.to_string()).collect(),
            claimed: false,
            interfaces: report(&sockets),
        }));

        let (sender, events) = mpsc::channel();
        let stop = Arc::new(AtomicBool::new(false));

        let thread = {
            let stop = Arc::clone(&stop);
            let state = Arc::clone(&state);
            let probe = config.probe;
            std::thread::Builder::new()
                .name("rk_mdns responder".into())
                .spawn(move || {
                    let mut engine = Engine {
                        original_instance: records.instance.labels()[0].clone(),
                        original_host: records.host.labels()[0].clone(),
                        attempt: 1,
                        sockets,
                        records,
                        events: sender,
                        stop,
                        state,
                    };
                    engine.run(probe);
                })
                .map_err(|e| StartError::InvalidArgument(format!("no thread: {e}")))?
        };

        Ok(Responder {
            events: Mutex::new(events),
            stop,
            state,
            thread: Mutex::new(Some(thread)),
        })
    }

    /// The next event, or `None` when the wait expired.
    pub fn poll(&self, timeout: Duration) -> Option<ResponderEvent> {
        let events = self.events.lock().ok()?;
        events.recv_timeout(timeout).ok()
    }

    /// What the responder ended up with — the names, the addresses, and what
    /// each interface has carried.
    pub fn state(&self) -> ResponderState {
        self.state
            .lock()
            .map(|s| s.clone())
            .unwrap_or_else(|poisoned| poisoned.into_inner().clone())
    }

    /// Stops the responder, and returns only after the goodbye has gone out.
    ///
    /// Joins the thread rather than detaching it: the goodbye is the whole
    /// point of a clean stop, and a caller that returned before it was sent
    /// would leave the record in every cache on the segment for its full
    /// lifetime.
    ///
    /// Stopping twice is not an error. During shutdown a second stop is
    /// ordinary, and making it one only teaches callers to ignore the result.
    pub fn stop(&self) {
        self.stop.store(true, AtomicOrdering::SeqCst);
        let thread = self.thread.lock().ok().and_then(|mut slot| slot.take());
        if let Some(thread) = thread {
            let _ = thread.join();
        }
    }

    /// Whether the responder's thread is still running.
    pub fn is_running(&self) -> bool {
        !self.stop.load(AtomicOrdering::SeqCst)
    }
}

impl Drop for Responder {
    fn drop(&mut self) {
        self.stop();
    }
}

fn report(sockets: &SocketSet) -> Vec<InterfaceReport> {
    sockets
        .sent_per_interface()
        .iter()
        .map(|entry| InterfaceReport {
            name: entry.interface.name.clone(),
            address: entry.interface.address.to_string(),
            index: entry.interface.index,
            sent: entry.sent(),
            failed: entry.failed(),
        })
        .collect()
}

struct Engine {
    sockets: SocketSet,
    records: ServiceRecords,
    /// The instance label as the caller gave it, kept so that attempt N is
    /// built from the original rather than from attempt N-1. See
    /// [`label_for_attempt`] for why the counter cannot be read back out of
    /// the label.
    original_instance: Vec<u8>,
    /// The host label as the caller gave it, for the same reason.
    original_host: Vec<u8>,
    /// Which try this is, from 1.
    attempt: u32,
    events: mpsc::Sender<ResponderEvent>,
    stop: Arc<AtomicBool>,
    state: Arc<Mutex<ResponderState>>,
}

impl Engine {
    /// Moves both names to the next attempt and returns the name left behind.
    fn rename(&mut self) -> String {
        let left_behind = self.records.instance.to_string();
        self.attempt += 1;
        let instance = label_for_attempt(&self.original_instance, self.attempt);
        let host = label_for_attempt(&self.original_host, self.attempt);
        self.records = self.records.renamed(&instance, &host);
        self.publish_state(false);
        left_behind
    }

    fn run(&mut self, probe: bool) {
        if probe && !self.probe_until_claimed() {
            return;
        }
        self.publish_state(true);

        let addresses = self
            .records
            .addresses
            .iter()
            .map(|a| a.to_string())
            .collect();
        self.emit(ResponderEvent::Claimed {
            instance: self.records.instance.to_string(),
            host: self.records.host.to_string(),
            addresses,
            interfaces: self.sockets.len(),
        });

        let mut announcements_left = ANNOUNCE_COUNT;
        let mut next_announcement = Instant::now();

        while !self.stopping() {
            if announcements_left > 0 && Instant::now() >= next_announcement {
                self.announce();
                announcements_left -= 1;
                next_announcement = Instant::now() + ANNOUNCE_INTERVAL;
            }
            if let Some(received) = self.sockets.recv(Duration::from_millis(100)) {
                self.handle(received.payload, received.from, received.interface_index);
            }
            self.publish_state(true);
        }

        let carried = {
            let goodbye = Message::response(self.records.goodbye()).encode();
            self.sockets.send_to_group(&goodbye)
        };
        self.emit(ResponderEvent::Goodbye { carried });
    }

    /// Probes, renames on conflict, and returns whether a name was claimed.
    fn probe_until_claimed(&mut self) -> bool {
        let mut renames = 0u32;
        // RFC 6762 §8.1: a random delay of up to 250 ms before the first
        // probe. Two tills powered on by the same switch would otherwise probe
        // in lockstep and conflict forever.
        self.sleep_interruptibly(Duration::from_millis(random_below(250)));

        loop {
            if self.stopping() {
                return false;
            }
            let mut conflict: Option<String> = None;

            for attempt in 1..=PROBE_COUNT {
                if self.stopping() {
                    return false;
                }
                self.emit(ResponderEvent::Probing {
                    instance: self.records.instance.to_string(),
                    host: self.records.host.to_string(),
                    attempt,
                });
                self.send_probe();

                let deadline = Instant::now() + PROBE_INTERVAL;
                while Instant::now() < deadline && conflict.is_none() {
                    let left = deadline.saturating_duration_since(Instant::now());
                    let Some(received) = self.sockets.recv(left) else {
                        break;
                    };
                    conflict = self.conflict_in(&received.payload);
                }
                if conflict.is_some() {
                    break;
                }
            }

            let Some(detail) = conflict else {
                return true;
            };

            renames += 1;
            if renames > MAX_RENAMES {
                self.emit(ResponderEvent::Error {
                    detail: format!(
                        "gave up after {MAX_RENAMES} renames — {} is contested by too many \
                         hosts for this to be a naming collision",
                        self.records.instance
                    ),
                });
                return false;
            }

            let from = self.rename();
            self.emit(ResponderEvent::NameConflict {
                from,
                to: self.records.instance.to_string(),
                detail,
            });

            // §8.1 rate limit: after a conflict, wait a second before probing
            // again, so two hosts fighting over a name do not saturate the
            // segment doing it.
            self.sleep_interruptibly(Duration::from_secs(1));
        }
    }

    fn send_probe(&mut self) {
        let questions: Vec<Question> = self
            .records
            .owned_names()
            .into_iter()
            .map(|name| Question {
                name,
                qtype: rtype::ANY,
                qclass: CLASS_IN,
                // §8.1: the first probe asks for a unicast reply, so a host
                // that already holds the name answers this prober directly
                // rather than the whole segment.
                unicast_response: true,
            })
            .collect();
        let mut probe = Message::query(questions, Vec::new());
        // §8.2: the records being claimed ride in the authority section. That
        // is what makes a tie-break possible when two hosts probe at once.
        probe.authority = self.records.claimed();
        let payload = probe.encode();
        self.sockets.send_to_group(&payload);
    }

    /// Whether this datagram says somebody else holds a name we want.
    fn conflict_in(&self, payload: &[u8]) -> Option<String> {
        let message = Message::decode(payload).ok()?;
        let ours = self.records.owned_names();

        if message.is_response() {
            for record in message.answers.iter().chain(message.additional.iter()) {
                if record.ttl == 0 {
                    // A goodbye is somebody leaving, not somebody holding.
                    continue;
                }
                if ours.iter().any(|name| name.eq_ignore_case(&record.name))
                    && !self
                        .records
                        .claimed()
                        .iter()
                        .any(|mine| mine.same_answer(record))
                {
                    return Some(format!(
                        "another host answered for {} with a {} record of its own",
                        record.name,
                        type_name(record.data.rtype())
                    ));
                }
            }
            return None;
        }

        // A simultaneous probe. §8.2: compare the proposed records, and the
        // loser renames. Both hosts run the same comparison on the same two
        // sets, so they reach opposite verdicts rather than both backing off.
        if !message.authority.is_empty()
            && message
                .questions
                .iter()
                .any(|q| ours.iter().any(|name| name.eq_ignore_case(&q.name)))
        {
            let theirs: Vec<Record> = message
                .authority
                .iter()
                .filter(|r| ours.iter().any(|name| name.eq_ignore_case(&r.name)))
                .cloned()
                .collect();
            if theirs.is_empty() {
                return None;
            }
            if tie_break(&self.records.claimed(), &theirs) == std::cmp::Ordering::Less {
                return Some(format!(
                    "another host is probing for {} at the same time and wins the tie-break \
                     of RFC 6762 §8.2",
                    self.records.instance
                ));
            }
        }
        None
    }

    fn announce(&mut self) {
        let payload = Message::response(self.records.announcement()).encode();
        let carried = self.sockets.send_to_group(&payload);
        let interfaces = self.sockets.len();
        self.emit(ResponderEvent::Announced {
            carried,
            interfaces,
        });
    }

    fn handle(&mut self, payload: Vec<u8>, from: SocketAddr, interface_index: usize) {
        let Ok(message) = Message::decode(&payload) else {
            // Anything on the group can send anything. A responder that
            // crashed on a bad datagram would be a host that stopped being
            // findable because somebody else's device is buggy.
            return;
        };

        if message.is_response() {
            // §9: a conflict found after claiming means starting over. Two
            // hosts on one name must not be the resting state.
            if message.is_authoritative() {
                if let Some(detail) = self.conflict_in(&payload) {
                    let from = self.rename();
                    self.emit(ResponderEvent::NameConflict {
                        from,
                        to: self.records.instance.to_string(),
                        detail,
                    });
                    self.announce();
                }
            }
            return;
        }

        if message.questions.is_empty() {
            return;
        }

        let mut answers: Vec<Record> = Vec::new();
        let mut additional: Vec<Record> = Vec::new();
        let mut unicast = false;
        let mut asked = Vec::new();

        for question in &message.questions {
            let answer = self.records.answer(question, &message.answers);
            if answer.is_empty() {
                continue;
            }
            asked.push(format!("{} {}", question.name, type_name(question.qtype)));
            // §5.4: honour the QU bit. A resolver on a network whose access
            // point drops multicast replies gets nothing otherwise, and the
            // failure looks like an absent till.
            unicast |= question.unicast_response;
            for record in answer.answers {
                if !answers.iter().any(|held| held.same_answer(&record)) {
                    answers.push(record);
                }
            }
            for record in answer.additional {
                if !additional.iter().any(|held| held.same_answer(&record)) {
                    additional.push(record);
                }
            }
        }

        if answers.is_empty() {
            return;
        }

        // A query carrying records in its authority section is a probe
        // (RFC 6762 §8.2), and this answer is the defence of a name.
        let is_probe = !message.authority.is_empty();

        let count = answers.len();
        let mut response = Message::response(answers);
        response.additional = additional;
        // A unicast reply echoes the query's id; a multicast one carries zero.
        if unicast {
            response.id = message.id;
        }
        let payload = response.encode();

        if unicast {
            self.sockets.send_unicast(interface_index, &payload, from);
        }
        // MEASURED 2026-08-06, and the reason this is not simply an `else`.
        //
        // A probe asks for a unicast reply (§8.1), and a unicast datagram
        // arriving on a **shared** port is delivered to exactly one of the
        // sockets bound to it — chosen by the operating system, not by us. On
        // Windows that is the last socket bound; on Linux with SO_REUSEPORT it
        // is whichever the hash picks. Port 5353 is always shared: Chrome holds
        // it on Windows, avahi-daemon holds it on Linux, mDNSResponder holds it
        // on every Mac.
        //
        // So the defence of a name can be handed to the wrong process and
        // dropped, and the prober then claims a name this host already holds —
        // silently, which is the one outcome probing exists to prevent. It was
        // found by two responders in one test process never seeing each other's
        // defence; the same thing happens between a till and a browser.
        //
        // §5.4 already permits multicasting the answer to a QU question, so
        // sending both costs one datagram and closes the hole.
        if !unicast || is_probe {
            self.sockets.send_to_group(&payload);
        }

        self.emit(ResponderEvent::Answered {
            question: asked.join(", "),
            to: from.to_string(),
            unicast,
            answers: count,
        });
    }

    fn publish_state(&self, claimed: bool) {
        if let Ok(mut state) = self.state.lock() {
            state.instance = self.records.instance.to_string();
            state.host = self.records.host.to_string();
            state.addresses = self
                .records
                .addresses
                .iter()
                .map(|a| a.to_string())
                .collect();
            state.claimed = claimed;
            state.interfaces = report(&self.sockets);
        }
    }

    fn emit(&self, event: ResponderEvent) {
        // A caller that stopped polling is not a reason to stop responding.
        let _ = self.events.send(event);
    }

    fn stopping(&self) -> bool {
        self.stop.load(AtomicOrdering::SeqCst)
    }

    fn sleep_interruptibly(&self, total: Duration) {
        let deadline = Instant::now() + total;
        while Instant::now() < deadline {
            if self.stopping() {
                return;
            }
            std::thread::sleep(Duration::from_millis(10).min(deadline - Instant::now()));
        }
    }
}

/// A readable name for a record type, for messages a person reads.
pub fn type_name(rtype: u16) -> &'static str {
    match rtype {
        crate::record::rtype::A => "A",
        crate::record::rtype::AAAA => "AAAA",
        crate::record::rtype::PTR => "PTR",
        crate::record::rtype::TXT => "TXT",
        crate::record::rtype::SRV => "SRV",
        crate::record::rtype::NSEC => "NSEC",
        crate::record::rtype::ANY => "ANY",
        _ => "?",
    }
}

/// A number below `limit`, from the clock.
///
/// A dependency on `rand` for one jitter value would pull in three crates and
/// a platform entropy source for something that only has to be *different* on
/// two machines that booted together. Nanoseconds since the epoch are.
fn random_below(limit: u64) -> u64 {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.subsec_nanos() as u64)
        .unwrap_or(0);
    let mut state = nanos ^ (std::process::id() as u64) << 32;
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    if limit == 0 {
        0
    } else {
        state % limit
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_config_with_an_unknown_key_is_refused() {
        // A typo must not look like a setting that took effect.
        let json = r#"{"instanceName":"till-3","serviceType":"_telepos._tcp.local",
                       "port":8443,"hostTtlSecond":120}"#;
        let parsed: Result<ResponderConfig, _> = serde_json::from_str(json);
        assert!(parsed.is_err());
    }

    #[test]
    fn the_defaults_are_the_ones_documented() {
        let json = r#"{"instanceName":"till-3","serviceType":"_telepos._tcp.local","port":8443}"#;
        let config: ResponderConfig = serde_json::from_str(json).expect("parses");
        assert_eq!(config.host_ttl_seconds, 120);
        assert_eq!(config.service_ttl_seconds, 4500);
        assert_eq!(config.mdns_port, MDNS_PORT);
        assert!(config.probe);
        assert!(config.ipv6);
        assert!(!config.loopback_interface);
        assert!(config.multicast_loopback);
    }

    #[test]
    fn a_nameless_or_portless_service_is_refused_before_a_socket_is_opened() {
        let base = ResponderConfig {
            instance_name: "till-3".into(),
            service_type: "_telepos._tcp.local".into(),
            host_name: None,
            port: 8443,
            txt: Vec::new(),
            addresses: Vec::new(),
            interfaces: Vec::new(),
            exclude_interfaces: Vec::new(),
            host_ttl_seconds: 120,
            service_ttl_seconds: 4500,
            mdns_port: 1,
            probe: false,
            ipv6: false,
            loopback_interface: true,
            multicast_loopback: true,
        };

        let mut nameless = base.clone();
        nameless.instance_name = "   ".into();
        assert!(matches!(
            Responder::start(nameless),
            Err(StartError::InvalidArgument(_))
        ));

        let mut portless = base.clone();
        portless.port = 0;
        assert!(matches!(
            Responder::start(portless),
            Err(StartError::InvalidArgument(_))
        ));

        let mut wrong_type = base.clone();
        wrong_type.service_type = "local".into();
        assert!(matches!(
            Responder::start(wrong_type),
            Err(StartError::InvalidArgument(_))
        ));

        let mut two_labels = base;
        two_labels.instance_name = "till.3".into();
        assert!(matches!(
            Responder::start(two_labels),
            Err(StartError::InvalidArgument(_))
        ));
    }

    #[test]
    fn random_below_stays_in_range() {
        for _ in 0..200 {
            assert!(random_below(250) < 250);
        }
        assert_eq!(random_below(0), 0);
    }
}
