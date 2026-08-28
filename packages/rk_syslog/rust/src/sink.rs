//! The sink: framing on the caller's thread, everything else on a worker.
//!
//! # What is guaranteed, and what is not
//!
//! **Order.** Records leave in the order they were submitted, across a crash
//! and a restart. The spool is a file read front to back and a cursor that
//! only moves forward.
//!
//! **At-least-once, not exactly-once.** The cursor advances after a record
//! has been written to the socket and flushed. A machine that dies in the
//! gap between the write and the cursor reaching disk resends that record on
//! restart, and the collector sees it twice. The alternative — advancing
//! first — turns the same gap into a lost record, and for a journal a
//! duplicate is a nuisance while a hole is a defect. There is nothing in
//! RFC 5425 to make this exact: the protocol has no application-level
//! acknowledgement to make "delivered" a thing either end can agree on.
//!
//! **Durability begins at the spool, not at submit.** See [`crate::queue`].
//!
//! **Gaps are counted, never silent.** Under the drop-oldest rule the worker
//! writes a record of its own into the spool saying how many were discarded,
//! so a reader of the journal sees the hole in the journal rather than having
//! to think to ask a counter.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crate::config::Settings;
use crate::queue::Queue;
use crate::rfc5424::{frame, Record, StructuredData, RK_SD_ID};
use crate::severity::Severity;
use crate::spool::Spool;
use crate::status::{Failure, Fallible, Status};
use crate::transport::Transport;

/// Counters, looked up by name.
///
/// By name for the same reason the enums are: a binding that reads counter
/// three gets a different number every time the list changes, and nothing
/// tells it. Asking for `"spool_dropped_records"` either answers or says it
/// does not know that name.
#[derive(Debug, Default)]
pub struct Counters {
    submitted: AtomicU64,
    framing_refused: AtomicU64,
    truncated: AtomicU64,
    queue_refused: AtomicU64,
    queue_dropped: AtomicU64,
    queue_depth: AtomicU64,
    spooled: AtomicU64,
    spool_refused: AtomicU64,
    spool_dropped_records: AtomicU64,
    spool_dropped_segments: AtomicU64,
    spool_torn_records: AtomicU64,
    spool_bytes: AtomicU64,
    spool_records: AtomicU64,
    spool_io_failures: AtomicU64,
    sent: AtomicU64,
    send_failures: AtomicU64,
    connected: AtomicU64,
}

/// Every counter name this version publishes.
pub const COUNTER_NAMES: &[&str] = &[
    "submitted",
    "framing_refused",
    "truncated",
    "queue_refused",
    "queue_dropped",
    "queue_depth",
    "spooled",
    "spool_refused",
    "spool_dropped_records",
    "spool_dropped_segments",
    "spool_torn_records",
    "spool_bytes",
    "spool_records",
    "spool_io_failures",
    "sent",
    "send_failures",
    "connected",
];

impl Counters {
    fn cell(&self, name: &str) -> Option<&AtomicU64> {
        Some(match name {
            "submitted" => &self.submitted,
            "framing_refused" => &self.framing_refused,
            "truncated" => &self.truncated,
            "queue_refused" => &self.queue_refused,
            "queue_dropped" => &self.queue_dropped,
            "queue_depth" => &self.queue_depth,
            "spooled" => &self.spooled,
            "spool_refused" => &self.spool_refused,
            "spool_dropped_records" => &self.spool_dropped_records,
            "spool_dropped_segments" => &self.spool_dropped_segments,
            "spool_torn_records" => &self.spool_torn_records,
            "spool_bytes" => &self.spool_bytes,
            "spool_records" => &self.spool_records,
            "spool_io_failures" => &self.spool_io_failures,
            "sent" => &self.sent,
            "send_failures" => &self.send_failures,
            "connected" => &self.connected,
            _ => return None,
        })
    }

    pub fn get(&self, name: &str) -> Option<u64> {
        self.cell(name).map(|c| c.load(Ordering::Relaxed))
    }

    fn bump(&self, name: &str, by: u64) {
        if let Some(cell) = self.cell(name) {
            cell.fetch_add(by, Ordering::Relaxed);
        }
    }

    fn set(&self, name: &str, value: u64) {
        if let Some(cell) = self.cell(name) {
            cell.store(value, Ordering::Relaxed);
        }
    }
}

/// A running syslog sink.
#[derive(Debug)]
pub struct Sink {
    settings: Settings,
    queue: Arc<Queue>,
    counters: Arc<Counters>,
    worker: Option<JoinHandle<()>>,
}

impl Sink {
    /// Opens the spool, checks the collector settings and starts the worker.
    ///
    /// Everything that can fail for a reason the caller can fix — an
    /// unwritable directory, a certificate that is not there, a bound smaller
    /// than a segment — fails here, as a returned value, before a single
    /// record has been submitted.
    pub fn open(settings: Settings) -> Fallible<Sink> {
        let spool = Spool::open(std::path::Path::new(&settings.spool_dir), settings.spool)?;
        let transport = Transport::new(settings.collector.clone())?;

        let counters = Arc::new(Counters::default());
        let stats = spool.stats();
        counters.set("spool_bytes", stats.bytes);
        counters.set("spool_records", stats.records);
        counters.set("spool_torn_records", stats.torn_records);

        let queue = Arc::new(Queue::new(settings.queue_capacity, settings.queue_policy));

        let worker = {
            let queue = Arc::clone(&queue);
            let counters = Arc::clone(&counters);
            let settings = settings.clone();
            std::thread::Builder::new()
                .name("rk_syslog".into())
                .spawn(move || run_worker(settings, queue, counters, spool, transport))
                .map_err(|e| {
                    Failure::new(
                        Status::SpoolIo,
                        format!("starting the rk_syslog worker thread: {e}"),
                    )
                })?
        };

        Ok(Sink {
            settings,
            queue,
            counters,
            worker: Some(worker),
        })
    }

    /// Frames a record and hands it to the worker.
    ///
    /// Touches no socket and no file. The only failures it can return are the
    /// ones it can decide here and now: a record that cannot be framed, and a
    /// hand-off queue that is full.
    pub fn submit(&self, record: &Record) -> Fallible<()> {
        self.counters.bump("submitted", 1);
        let framed = match frame(
            &self.settings.identity,
            record,
            self.settings.max_message_bytes,
            self.settings.oversize,
            self.settings.emit_bom,
        ) {
            Ok(framed) => framed,
            Err(failure) => {
                self.counters.bump("framing_refused", 1);
                return Err(failure);
            }
        };
        if framed.truncated_from.is_some() {
            self.counters.bump("truncated", 1);
        }
        match self.queue.push(framed.bytes) {
            Ok(()) => {
                self.counters.set("queue_depth", self.queue.len() as u64);
                Ok(())
            }
            Err(failure) => {
                if failure.status == Status::QueueFull {
                    self.counters.bump("queue_refused", 1);
                }
                Err(failure)
            }
        }
    }

    /// Waits until everything submitted so far has reached the spool.
    ///
    /// The one call here that blocks, and only the caller who asks for it.
    /// Use it at shutdown, and at any point where a record must be on disk
    /// before the next thing happens. It says nothing about delivery — the
    /// collector may be unreachable for days and this still returns.
    pub fn flush(&self, timeout: Duration) -> Fallible<()> {
        self.queue.wait_drained(timeout)
    }

    pub fn stat(&self, name: &str) -> Option<u64> {
        if name == "queue_depth" {
            return Some(self.queue.len() as u64);
        }
        self.counters.get(name)
    }

    pub fn settings(&self) -> &Settings {
        &self.settings
    }
}

impl Drop for Sink {
    /// Closes the queue and joins the worker, so a closed sink has written
    /// everything it accepted. Deterministic on purpose: nothing here waits
    /// for a garbage collector to notice.
    fn drop(&mut self) {
        self.queue.close();
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}

/// How long the worker sleeps when there is nothing to do. Short enough that
/// a retry after a failed send is not delayed by an idle queue.
const IDLE_WAIT: Duration = Duration::from_millis(250);

/// Records sent per pass before going back to look at the queue, so a large
/// backlog cannot starve the hand-off.
const SEND_BATCH: usize = 256;

fn run_worker(
    settings: Settings,
    queue: Arc<Queue>,
    counters: Arc<Counters>,
    mut spool: Spool,
    mut transport: Transport,
) {
    let mut backoff = settings.retry_min;
    let mut next_attempt = Instant::now();

    loop {
        let (batch, closed) = queue.drain_blocking(IDLE_WAIT);
        for record in &batch {
            match spool.append(record) {
                Ok(()) => counters.bump("spooled", 1),
                Err(failure) => {
                    if failure.status == Status::SpoolFull {
                        counters.bump("spool_refused", 1);
                    } else {
                        counters.bump("spool_io_failures", 1);
                    }
                }
            }
        }
        if !batch.is_empty() {
            let _ = spool.flush();
        }
        queue.mark_drained();

        let queue_dropped = queue.take_dropped();
        if queue_dropped > 0 {
            counters.bump("queue_dropped", queue_dropped);
            announce_loss(&settings, &mut spool, "queueDropped", queue_dropped);
        }

        let dropped = spool.take_dropped();
        if dropped > 0 {
            counters.bump("spool_dropped_records", dropped);
            // The hole is written into the journal, not only into a counter.
            announce_loss(&settings, &mut spool, "spoolDropped", dropped);
        }

        let stats = spool.stats();
        counters.set("spool_bytes", stats.bytes);
        counters.set("spool_records", stats.records);
        counters.set("spool_dropped_segments", stats.dropped_segments);
        counters.set("spool_torn_records", stats.torn_records);
        counters.set("queue_depth", queue.len() as u64);

        if transport.is_enabled() && Instant::now() >= next_attempt {
            let mut sent = 0usize;
            loop {
                if sent >= SEND_BATCH {
                    break;
                }
                let record = match spool.peek() {
                    Ok(Some(record)) => record,
                    Ok(None) => break,
                    Err(_) => break,
                };
                match transport.send(&record) {
                    Ok(()) => {
                        // Only now does the cursor move. A crash before this
                        // line resends the record; a crash after it does not.
                        // See the at-least-once note at the top of this file.
                        if spool.advance(record.len()).is_err() {
                            break;
                        }
                        counters.bump("sent", 1);
                        counters.set("connected", 1);
                        sent += 1;
                        backoff = settings.retry_min;
                    }
                    Err(_) => {
                        counters.bump("send_failures", 1);
                        counters.set("connected", 0);
                        transport.disconnect();
                        next_attempt = Instant::now() + backoff;
                        backoff = (backoff * 2).min(settings.retry_max);
                        break;
                    }
                }
            }
        }

        if closed && queue.is_empty() {
            let _ = spool.flush();
            return;
        }
    }
}

/// Writes a record saying that records were lost, into the place the lost
/// records would have been.
fn announce_loss(settings: &Settings, spool: &mut Spool, what: &str, count: u64) {
    let micros = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_micros() as i64)
        .unwrap_or(0);
    let mut sd = StructuredData::new();
    if sd.push_element(RK_SD_ID).is_err() {
        return;
    }
    if sd.push_param(what, &count.to_string()).is_err() {
        return;
    }
    let record = Record {
        facility: settings.facility,
        severity: Severity::Warning,
        epoch_micros: micros,
        utc_offset_minutes: 0,
        msgid: Some("RKLOSS".into()),
        structured_data: sd,
        message: Some(format!(
            "rk_syslog discarded {count} record(s) to stay inside its bound ({what})"
        )),
    };
    if let Ok(framed) = frame(
        &settings.identity,
        &record,
        settings.max_message_bytes,
        settings.oversize,
        settings.emit_bom,
    ) {
        let _ = spool.append(&framed.bytes);
    }
}
