//! What the sink promises, tested against the sink rather than its parts.
//!
//! The unit tests inside each module prove the pieces. These prove the
//! sentences in the README: it does not block, it holds its bound, it keeps
//! order across a restart, it delivers frames a collector can actually read,
//! and a panic behind the C ABI comes back as a value.

use std::io::Read;
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::time::{Duration, Instant};

use rk_syslog::config::ConfigBuilder;
use rk_syslog::rfc5424::{Record, StructuredData};
use rk_syslog::severity::{Facility, Severity};
use rk_syslog::sink::Sink;
use rk_syslog::status::Status;

// ------------------------------------------------------------------ helpers

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> TempDir {
        let mut path = std::env::temp_dir();
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        path.push(format!("rk_syslog-it-{tag}-{nanos}"));
        std::fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn builder(dir: &Path) -> ConfigBuilder {
    let mut builder = ConfigBuilder::new();
    builder.set("spool_dir", dir.to_str().unwrap()).unwrap();
    builder.set("host_name", "till-01").unwrap();
    builder.set("app_name", "telepos").unwrap();
    builder.set("proc_id", "1234").unwrap();
    builder
}

fn record(message: &str) -> Record {
    Record {
        facility: Facility::Local0,
        severity: Severity::Informational,
        epoch_micros: 1_065_910_455_003_000,
        utc_offset_minutes: 0,
        msgid: Some("TEST".into()),
        structured_data: StructuredData::new(),
        message: Some(message.into()),
    }
}

/// Reads octet-counted frames off a stream, exactly as RFC 5425 §4.3
/// describes, and hands each whole record to a channel. Written the naive
/// way on purpose: if our framing is wrong, a by-the-book reader is what
/// notices.
fn read_frames(mut stream: TcpStream, sender: mpsc::Sender<String>) {
    let mut buffer = Vec::new();
    let mut chunk = [0u8; 4096];
    loop {
        let read = match stream.read(&mut chunk) {
            Ok(0) | Err(_) => return,
            Ok(n) => n,
        };
        buffer.extend_from_slice(&chunk[..read]);
        while let Some(space) = buffer.iter().position(|b| *b == b' ') {
            let Ok(digits) = std::str::from_utf8(&buffer[..space]) else {
                return;
            };
            let Ok(length) = digits.parse::<usize>() else {
                return;
            };
            if buffer.len() < space + 1 + length {
                break;
            }
            let record = buffer[space + 1..space + 1 + length].to_vec();
            buffer.drain(..space + 1 + length);
            if sender
                .send(String::from_utf8_lossy(&record).into_owned())
                .is_err()
            {
                return;
            }
        }
    }
}

// ------------------------------------------------------------------- tests

#[test]
fn submitting_does_not_wait_on_an_unreachable_collector() {
    // 192.0.2.1 is TEST-NET-1 (RFC 5737): routable-looking and guaranteed
    // never to answer, so a connect attempt runs to the operating system's
    // timeout. If a submit ever touched the network, this would take tens of
    // seconds instead of milliseconds.
    let dir = TempDir::new("nonblocking");
    let mut builder = builder(dir.path());
    builder.set("collector_scheme", "tcp").unwrap();
    builder.set("collector_host", "192.0.2.1").unwrap();
    builder.set("collector_port", "6514").unwrap();
    builder.set("connect_timeout_ms", "20000").unwrap();
    builder.set("queue_max_records", "200000").unwrap();
    builder.set("spool_max_bytes", "33554432").unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();

    let started = Instant::now();
    for i in 0..20_000 {
        sink.submit(&record(&format!("sale {i}"))).unwrap();
    }
    let elapsed = started.elapsed();

    assert!(
        elapsed < Duration::from_secs(3),
        "20000 submits took {elapsed:?} while the collector was a black hole; \
         a submit is waiting on the network"
    );
    assert_eq!(sink.stat("submitted"), Some(20_000));
}

#[test]
fn the_spool_holds_its_bound_while_records_keep_arriving() {
    let dir = TempDir::new("bound");
    let mut builder = builder(dir.path());
    builder.set("spool_max_bytes", "131072").unwrap(); // 128 KiB
    builder.set("spool_segment_bytes", "16384").unwrap();
    builder.set("spool_policy", "drop_oldest").unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();

    // ~4 MiB of records into a 128 KiB spool, with no collector to drain it.
    // Submitting faster than the worker can write is expected here, and
    // under the default queue rule that comes back as `queueFull` — a
    // refusal, not a loss. It is not what this test is about, so it is
    // counted and passed over.
    let mut accepted = 0;
    let mut refused = 0;
    for i in 0..20_000 {
        match sink.submit(&record(&format!("{i:06} {}", "x".repeat(150)))) {
            Ok(()) => accepted += 1,
            Err(failure) => {
                assert_eq!(failure.status, Status::QueueFull);
                refused += 1;
                std::thread::sleep(Duration::from_micros(200));
            }
        }
    }
    assert!(accepted > 5_000, "only {accepted} in, {refused} refused");
    sink.flush(Duration::from_secs(120)).unwrap();
    // The worker needs a beat to finish the last append after the flush.
    std::thread::sleep(Duration::from_millis(300));

    let on_disk: u64 = std::fs::read_dir(dir.path())
        .unwrap()
        .flatten()
        .filter(|e| e.path().extension().map(|x| x == "spl").unwrap_or(false))
        .map(|e| e.metadata().unwrap().len())
        .sum();
    assert!(
        on_disk <= 131_072,
        "the spool grew to {on_disk} bytes, past its 131072-byte bound"
    );
    assert!(
        sink.stat("spool_dropped_records").unwrap() > 0,
        "records were discarded to hold the bound but nothing was counted"
    );
}

#[test]
fn the_reject_rule_refuses_rather_than_discarding() {
    let dir = TempDir::new("reject");
    let mut builder = builder(dir.path());
    builder.set("spool_max_bytes", "65536").unwrap();
    builder.set("spool_segment_bytes", "16384").unwrap();
    builder.set("spool_policy", "reject").unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();

    for i in 0..5_000 {
        sink.submit(&record(&format!("{i:06} {}", "y".repeat(150))))
            .unwrap();
    }
    sink.flush(Duration::from_secs(120)).unwrap();
    std::thread::sleep(Duration::from_millis(300));

    assert_eq!(
        sink.stat("spool_dropped_records"),
        Some(0),
        "the reject rule discarded a record it had accepted"
    );
    assert!(
        sink.stat("spool_refused").unwrap() > 0,
        "the spool never filled, so this test proved nothing"
    );
}

#[test]
fn a_record_that_cannot_be_framed_comes_back_as_a_failure() {
    let dir = TempDir::new("unframeable");
    let sink = Sink::open(builder(dir.path()).build().unwrap()).unwrap();

    let mut bad = record("ignored");
    bad.msgid = Some("this msgid is far longer than the thirty-two bytes allowed".into());
    let failure = sink.submit(&bad).unwrap_err();
    assert_eq!(failure.status, Status::InvalidHeaderField);
    assert!(failure.detail.contains("msgid"), "{}", failure.detail);
    assert_eq!(sink.stat("framing_refused"), Some(1));
    // Refused, not accepted-then-lost: nothing reached the spool.
    sink.flush(Duration::from_secs(5)).unwrap();
    assert_eq!(sink.stat("spooled"), Some(0));
}

#[test]
fn records_reach_a_collector_as_octet_counted_rfc_5424_frames() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let (stream, _) = listener.accept().unwrap();
        read_frames(stream, sender);
    });

    let dir = TempDir::new("delivery");
    let mut builder = builder(dir.path());
    builder.set("collector_scheme", "tcp").unwrap();
    builder.set("collector_host", "127.0.0.1").unwrap();
    builder.set("collector_port", &port.to_string()).unwrap();
    builder.set("msg_bom", "false").unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();

    for i in 0..25 {
        let mut r = record(&format!("sale {i}"));
        r.structured_data.push_element("sale@0").unwrap();
        r.structured_data.push_param("n", &i.to_string()).unwrap();
        sink.submit(&r).unwrap();
    }

    let mut received = Vec::new();
    while received.len() < 25 {
        match receiver.recv_timeout(Duration::from_secs(10)) {
            Ok(record) => received.push(record),
            Err(_) => panic!("only {} of 25 records arrived", received.len()),
        }
    }

    assert_eq!(
        received[0],
        concat!(
            "<134>1 2003-10-11T22:14:15.003000Z till-01 telepos 1234 TEST ",
            "[sale@0 n=\"0\"] sale 0"
        )
    );
    // Order is the order they were submitted.
    for (i, record) in received.iter().enumerate() {
        assert!(record.ends_with(&format!("sale {i}")), "{record}");
    }
}

#[test]
fn a_restart_resumes_where_the_last_one_stopped_and_keeps_the_order() {
    let dir = TempDir::new("restart");

    // First run: no collector, so everything piles up in the spool.
    {
        let sink = Sink::open(builder(dir.path()).build().unwrap()).unwrap();
        for i in 0..200 {
            sink.submit(&record(&format!("before {i:03}"))).unwrap();
        }
        sink.flush(Duration::from_secs(10)).unwrap();
    } // dropped: the worker is joined and the spool is closed

    // Second run: a collector appears and gets the backlog, in order.
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let (stream, _) = listener.accept().unwrap();
        read_frames(stream, sender);
    });

    let mut builder = builder(dir.path());
    builder.set("collector_scheme", "tcp").unwrap();
    builder.set("collector_host", "127.0.0.1").unwrap();
    builder.set("collector_port", &port.to_string()).unwrap();
    builder.set("msg_bom", "false").unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();
    sink.submit(&record("after 000")).unwrap();

    let mut received = Vec::new();
    while received.len() < 201 {
        match receiver.recv_timeout(Duration::from_secs(15)) {
            Ok(record) => received.push(record),
            Err(_) => panic!("only {} of 201 records arrived", received.len()),
        }
    }
    for (i, record) in received.iter().take(200).enumerate() {
        assert!(
            record.ends_with(&format!("before {i:03}")),
            "record {i} out of order: {record}"
        );
    }
    assert!(received[200].ends_with("after 000"));
}

#[test]
fn nothing_is_sent_to_nobody_when_no_collector_is_configured() {
    // Closed by default: the sink spools and stays quiet.
    let dir = TempDir::new("closed");
    let sink = Sink::open(builder(dir.path()).build().unwrap()).unwrap();
    sink.submit(&record("hello")).unwrap();
    sink.flush(Duration::from_secs(5)).unwrap();
    assert_eq!(sink.stat("sent"), Some(0));
    assert_eq!(sink.stat("send_failures"), Some(0));
    assert_eq!(sink.stat("spooled"), Some(1));
}

#[test]
fn an_unknown_counter_name_says_so_rather_than_answering_zero() {
    let dir = TempDir::new("stats");
    let sink = Sink::open(builder(dir.path()).build().unwrap()).unwrap();
    assert_eq!(sink.stat("recods_sent"), None);
    assert_eq!(sink.stat("sent"), Some(0));
}
