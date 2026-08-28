//! The bounded on-disk spool.
//!
//! # What it is for
//!
//! A till must keep selling when the collector is unreachable, and the
//! records produced while it was unreachable must still be there afterwards —
//! including after the process dies. Memory gives one and not the other, so
//! the records go to disk.
//!
//! # The bound, and what it costs
//!
//! Unbounded is not an option: a collector that is down for a fortnight would
//! otherwise fill the disk of the machine taking money, and a till that
//! cannot write is a till that cannot sell. So there is a byte bound, and
//! something has to give when it is reached. Two rules, chosen when the sink
//! opens:
//!
//! - [`SpoolPolicy::DropOldest`] — the oldest **whole segment** is deleted.
//!   Cost: those records are gone for good, and the granularity is a segment,
//!   so up to `segment_bytes` disappear at once rather than one record. What
//!   survives is the count, in `dropped_records`, and a record announcing the
//!   deletion is written into the spool in their place. This is the rule for
//!   the technical journal, where recent detail is what an engineer needs.
//!
//! - [`SpoolPolicy::Reject`] — nothing is ever deleted. An append past the
//!   bound fails with [`Status::SpoolFull`]. Cost: the failure moves to the
//!   caller, who now has a record and nowhere to put it. This is the rule for
//!   audit and security, where a discarded record is a defect and the caller
//!   has its own durable store to fall back on.
//!
//! Neither rule loses a record without saying so. That is the whole
//! requirement; which of the two costs to pay is the operator's decision, not
//! ours.
//!
//! # The bound is enforced on the write path
//!
//! Every append checks the bound before it writes. There is no sweeper, no
//! timer and no periodic task, because a retention rule that depends on
//! something remembering to run is a retention rule that will one day not
//! run — this project has already been bitten by that, twice. If a record
//! goes in, the check ran.
//!
//! # On-disk shape
//!
//! ```text
//! <dir>/seg-00000000000000000001.spl   records, each  u32 length LE + payload
//! <dir>/cursor                          "<segment seq> <byte offset>\n"
//! ```
//!
//! Recovery reads the segments in sequence order and the cursor. A record cut
//! short by a crash mid-write is detected — its length prefix runs past the
//! end of the file — and the segment is truncated back to the last whole
//! record, with the loss counted in `torn_records` rather than passed on as a
//! corrupt frame.

use std::collections::VecDeque;
use std::fs::{self, File, OpenOptions};
use std::io::{BufWriter, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};

use crate::status::{Failure, Fallible, Status};

/// What the spool does when it is full.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpoolPolicy {
    /// Delete the oldest segment to make room.
    DropOldest,
    /// Refuse the append and tell the caller.
    Reject,
}

impl SpoolPolicy {
    pub const fn name(self) -> &'static str {
        match self {
            SpoolPolicy::DropOldest => "drop_oldest",
            SpoolPolicy::Reject => "reject",
        }
    }

    pub fn from_name(name: &str) -> Option<SpoolPolicy> {
        match name {
            "drop_oldest" => Some(SpoolPolicy::DropOldest),
            "reject" => Some(SpoolPolicy::Reject),
            _ => None,
        }
    }
}

/// How the spool is sized.
#[derive(Debug, Clone, Copy)]
pub struct SpoolLimits {
    pub max_bytes: u64,
    pub segment_bytes: u64,
    pub policy: SpoolPolicy,
}

/// What the spool has done, for whoever asks.
#[derive(Debug, Clone, Copy, Default)]
pub struct SpoolStats {
    pub bytes: u64,
    pub records: u64,
    pub dropped_records: u64,
    pub dropped_segments: u64,
    pub torn_records: u64,
}

#[derive(Debug)]
struct Segment {
    seq: u64,
    path: PathBuf,
    bytes: u64,
    records: u64,
}

/// Length prefix width: a `u32` little-endian byte count in front of each
/// record.
const PREFIX: usize = 4;

/// A durable, ordered, bounded queue of framed records.
#[derive(Debug)]
pub struct Spool {
    dir: PathBuf,
    limits: SpoolLimits,
    segments: VecDeque<Segment>,
    next_seq: u64,
    writer: Option<BufWriter<File>>,
    /// Segment sequence the read cursor sits in.
    read_seq: u64,
    /// Byte offset of the next unsent record inside that segment.
    read_offset: u64,
    stats: SpoolStats,
}

fn io_failure(what: &str, err: std::io::Error) -> Failure {
    Failure::new(Status::SpoolIo, format!("{what}: {err}"))
}

impl Spool {
    /// Opens (and creates) a spool directory, recovering whatever is there.
    pub fn open(dir: &Path, limits: SpoolLimits) -> Fallible<Spool> {
        if limits.segment_bytes == 0 || limits.max_bytes < limits.segment_bytes {
            return Err(Failure::new(
                Status::InvalidConfigValue,
                format!(
                    "spool_max_bytes ({}) must be at least spool_segment_bytes ({}), \
                     and neither may be zero",
                    limits.max_bytes, limits.segment_bytes
                ),
            ));
        }
        fs::create_dir_all(dir).map_err(|e| io_failure("creating the spool directory", e))?;

        let mut spool = Spool {
            dir: dir.to_path_buf(),
            limits,
            segments: VecDeque::new(),
            next_seq: 1,
            writer: None,
            read_seq: 0,
            read_offset: 0,
            stats: SpoolStats::default(),
        };
        spool.recover()?;
        Ok(spool)
    }

    fn segment_path(dir: &Path, seq: u64) -> PathBuf {
        dir.join(format!("seg-{seq:020}.spl"))
    }

    fn cursor_path(&self) -> PathBuf {
        self.dir.join("cursor")
    }

    fn recover(&mut self) -> Fallible<()> {
        let entries =
            fs::read_dir(&self.dir).map_err(|e| io_failure("reading the spool directory", e))?;
        let mut found: Vec<(u64, PathBuf)> = Vec::new();
        for entry in entries {
            let entry = entry.map_err(|e| io_failure("listing the spool directory", e))?;
            let path = entry.path();
            let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
                continue;
            };
            let Some(rest) = name.strip_prefix("seg-") else {
                continue;
            };
            let Some(digits) = rest.strip_suffix(".spl") else {
                continue;
            };
            if let Ok(seq) = digits.parse::<u64>() {
                found.push((seq, path));
            }
        }
        found.sort_by_key(|(seq, _)| *seq);

        for (seq, path) in found {
            let (bytes, records, torn) = Self::scan_segment(&path)?;
            self.stats.torn_records += torn;
            if bytes == 0 {
                // An empty segment carries nothing; a leftover is noise.
                let _ = fs::remove_file(&path);
                continue;
            }
            self.stats.bytes += bytes;
            self.stats.records += records;
            self.next_seq = self.next_seq.max(seq + 1);
            self.segments.push_back(Segment {
                seq,
                path,
                bytes,
                records,
            });
        }

        let (seq, offset) = self.read_cursor();
        self.read_seq = seq;
        self.read_offset = offset;
        // A cursor that points at a segment we no longer have (dropped, or
        // fully sent and deleted) starts at the oldest segment we do have.
        let oldest = self
            .segments
            .front()
            .map(|s| s.seq)
            .unwrap_or(self.next_seq);
        if self.read_seq < oldest {
            self.read_seq = oldest;
            self.read_offset = 0;
        }
        Ok(())
    }

    /// Walks a segment, returning its whole-record length, its record count,
    /// and how many records a torn tail cost. Truncates the file if the tail
    /// is torn.
    fn scan_segment(path: &Path) -> Fallible<(u64, u64, u64)> {
        let mut file = OpenOptions::new()
            .read(true)
            .write(true)
            .open(path)
            .map_err(|e| io_failure("opening a spool segment", e))?;
        let total = file
            .metadata()
            .map_err(|e| io_failure("sizing a spool segment", e))?
            .len();

        let mut good = 0u64;
        let mut records = 0u64;
        let mut prefix = [0u8; PREFIX];
        loop {
            if good + PREFIX as u64 > total {
                break;
            }
            file.seek(SeekFrom::Start(good))
                .map_err(|e| io_failure("seeking in a spool segment", e))?;
            if file.read_exact(&mut prefix).is_err() {
                break;
            }
            let len = u32::from_le_bytes(prefix) as u64;
            if len == 0 || good + PREFIX as u64 + len > total {
                break;
            }
            good += PREFIX as u64 + len;
            records += 1;
        }

        let torn = if good < total {
            file.set_len(good)
                .map_err(|e| io_failure("truncating a torn spool segment", e))?;
            1
        } else {
            0
        };
        Ok((good, records, torn))
    }

    fn read_cursor(&self) -> (u64, u64) {
        let Ok(text) = fs::read_to_string(self.cursor_path()) else {
            return (0, 0);
        };
        let mut parts = text.split_whitespace();
        let seq = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
        let offset = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
        (seq, offset)
    }

    fn write_cursor(&self) -> Fallible<()> {
        // Written to a temporary file and renamed, so a crash leaves either
        // the old cursor or the new one and never half of either.
        //
        // Deliberately no `fsync`. The cursor says how far delivery got; the
        // records themselves are in the segments. Losing the last cursor
        // update to a power cut costs a resend, and this sink already
        // promises at-least-once — so an `fsync` here would buy nothing and
        // cost one disk barrier per delivered record on a machine that is
        // taking money. Measured on this test suite: the barrier was 98s of
        // an 8-test run.
        let tmp = self.dir.join("cursor.tmp");
        {
            let mut file =
                File::create(&tmp).map_err(|e| io_failure("creating the cursor file", e))?;
            writeln!(file, "{} {}", self.read_seq, self.read_offset)
                .map_err(|e| io_failure("writing the cursor file", e))?;
        }
        fs::rename(&tmp, self.cursor_path())
            .map_err(|e| io_failure("replacing the cursor file", e))?;
        Ok(())
    }

    /// Appends one framed record, enforcing the bound first.
    pub fn append(&mut self, payload: &[u8]) -> Fallible<()> {
        let need = PREFIX as u64 + payload.len() as u64;
        if need > self.limits.max_bytes {
            return Err(Failure::new(
                Status::SpoolFull,
                format!(
                    "a single {need}-byte record cannot fit in a spool bounded at {} bytes",
                    self.limits.max_bytes
                ),
            ));
        }
        self.make_room(need)?;
        self.append_unchecked(payload)
    }

    /// The bound. Called by every append, before any byte is written.
    fn make_room(&mut self, need: u64) -> Fallible<()> {
        while self.stats.bytes + need > self.limits.max_bytes {
            match self.limits.policy {
                SpoolPolicy::Reject => {
                    return Err(Failure::new(
                        Status::SpoolFull,
                        format!(
                            "spool holds {} of {} bytes and the rule is 'reject'; \
                             the record was not accepted",
                            self.stats.bytes, self.limits.max_bytes
                        ),
                    ));
                }
                SpoolPolicy::DropOldest => {
                    if self.segments.len() <= 1 {
                        // Nothing older to drop than the segment being
                        // written. Close it so it becomes droppable.
                        self.roll_segment()?;
                    }
                    if self.segments.is_empty() {
                        return Err(Failure::new(
                            Status::SpoolIo,
                            "the spool is over its bound with no segments to drop".to_string(),
                        ));
                    }
                    self.drop_oldest_segment()?;
                }
            }
        }
        Ok(())
    }

    fn drop_oldest_segment(&mut self) -> Fallible<()> {
        let Some(segment) = self.segments.pop_front() else {
            return Ok(());
        };
        fs::remove_file(&segment.path)
            .map_err(|e| io_failure("deleting the oldest spool segment", e))?;
        self.stats.bytes = self.stats.bytes.saturating_sub(segment.bytes);
        self.stats.records = self.stats.records.saturating_sub(segment.records);
        self.stats.dropped_segments += 1;

        // Only the part the collector had not yet been sent is a loss; a
        // segment already delivered is just cleanup.
        if self.read_seq <= segment.seq {
            self.stats.dropped_records += segment.records;
            let oldest = self
                .segments
                .front()
                .map(|s| s.seq)
                .unwrap_or(self.next_seq);
            self.read_seq = oldest;
            self.read_offset = 0;
            let _ = self.write_cursor();
        }
        Ok(())
    }

    fn roll_segment(&mut self) -> Fallible<()> {
        if let Some(writer) = self.writer.as_mut() {
            writer
                .flush()
                .map_err(|e| io_failure("flushing a spool segment before rolling", e))?;
        }
        self.writer = None;
        Ok(())
    }

    fn append_unchecked(&mut self, payload: &[u8]) -> Fallible<()> {
        let need = PREFIX as u64 + payload.len() as u64;

        let roll = match self.segments.back() {
            None => true,
            Some(last) => self.writer.is_none() || last.bytes + need > self.limits.segment_bytes,
        };
        if roll {
            self.roll_segment()?;
            let seq = self.next_seq;
            self.next_seq += 1;
            let path = Self::segment_path(&self.dir, seq);
            let file = OpenOptions::new()
                .create(true)
                .append(true)
                .open(&path)
                .map_err(|e| io_failure("creating a spool segment", e))?;
            self.writer = Some(BufWriter::new(file));
            self.segments.push_back(Segment {
                seq,
                path,
                bytes: 0,
                records: 0,
            });
            if self.read_seq == 0 {
                self.read_seq = seq;
                self.read_offset = 0;
            }
        }

        let writer = self
            .writer
            .as_mut()
            .expect("a segment was just opened for writing");
        writer
            .write_all(&(payload.len() as u32).to_le_bytes())
            .map_err(|e| io_failure("writing a record length", e))?;
        writer
            .write_all(payload)
            .map_err(|e| io_failure("writing a record", e))?;

        let last = self.segments.back_mut().expect("a segment was just pushed");
        last.bytes += need;
        last.records += 1;
        self.stats.bytes += need;
        self.stats.records += 1;
        Ok(())
    }

    /// Pushes buffered writes to the operating system.
    ///
    /// Not an `fsync`: this makes the records survive the process dying,
    /// which is what the requirement asks for, without paying a disk barrier
    /// on the path of a machine that is taking money. Surviving the power
    /// going out mid-write is what the torn-tail recovery is for.
    pub fn flush(&mut self) -> Fallible<()> {
        if let Some(writer) = self.writer.as_mut() {
            writer
                .flush()
                .map_err(|e| io_failure("flushing the spool", e))?;
        }
        Ok(())
    }

    /// The record at the cursor, without consuming it.
    ///
    /// Peek-then-[`advance`](Self::advance) rather than pop, because the
    /// cursor may only move once the record is on the wire. A pop would put
    /// the record in memory, where a crash between the read and the send
    /// loses it.
    pub fn peek(&mut self) -> Fallible<Option<Vec<u8>>> {
        self.flush()?;
        loop {
            let Some(segment) = self.segments.iter().find(|s| s.seq == self.read_seq) else {
                // The cursor is past everything we hold.
                match self.segments.front() {
                    Some(front) if front.seq > self.read_seq => {
                        self.read_seq = front.seq;
                        self.read_offset = 0;
                        continue;
                    }
                    _ => return Ok(None),
                }
            };
            if self.read_offset >= segment.bytes {
                // Segment exhausted. Move on, and delete it if it is not the
                // one being written.
                let seq = segment.seq;
                let is_last = self.segments.back().map(|s| s.seq) == Some(seq);
                let Some(next) = self.segments.iter().find(|s| s.seq > seq).map(|s| s.seq) else {
                    return Ok(None);
                };
                if !is_last {
                    self.remove_segment(seq)?;
                }
                self.read_seq = next;
                self.read_offset = 0;
                self.write_cursor()?;
                continue;
            }

            let mut file = File::open(&segment.path)
                .map_err(|e| io_failure("opening a spool segment to read", e))?;
            file.seek(SeekFrom::Start(self.read_offset))
                .map_err(|e| io_failure("seeking to the spool cursor", e))?;
            let mut prefix = [0u8; PREFIX];
            file.read_exact(&mut prefix)
                .map_err(|e| io_failure("reading a record length", e))?;
            let len = u32::from_le_bytes(prefix) as usize;
            let mut payload = vec![0u8; len];
            file.read_exact(&mut payload)
                .map_err(|e| io_failure("reading a record", e))?;
            return Ok(Some(payload));
        }
    }

    /// Moves the cursor past the record [`peek`](Self::peek) returned and
    /// writes the new position down.
    pub fn advance(&mut self, payload_len: usize) -> Fallible<()> {
        self.read_offset += PREFIX as u64 + payload_len as u64;
        self.write_cursor()
    }

    fn remove_segment(&mut self, seq: u64) -> Fallible<()> {
        if let Some(pos) = self.segments.iter().position(|s| s.seq == seq) {
            let segment = self.segments.remove(pos).expect("position just found");
            let _ = fs::remove_file(&segment.path);
            self.stats.bytes = self.stats.bytes.saturating_sub(segment.bytes);
            self.stats.records = self.stats.records.saturating_sub(segment.records);
        }
        Ok(())
    }

    pub fn stats(&self) -> SpoolStats {
        self.stats
    }

    /// Bytes actually on disk, counted from the filesystem rather than from
    /// the running total. The two agreeing is what makes the bound a fact
    /// instead of a claim.
    pub fn bytes_on_disk(&self) -> u64 {
        let Ok(entries) = fs::read_dir(&self.dir) else {
            return 0;
        };
        entries
            .flatten()
            .filter(|e| e.path().extension().map(|x| x == "spl").unwrap_or(false))
            .filter_map(|e| e.metadata().ok())
            .map(|m| m.len())
            .sum()
    }

    /// Takes the dropped-record count and resets it, so the caller can turn
    /// it into a record exactly once.
    pub fn take_dropped(&mut self) -> u64 {
        std::mem::take(&mut self.stats.dropped_records)
    }

    pub fn limits(&self) -> SpoolLimits {
        self.limits
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TempDir(PathBuf);

    impl TempDir {
        fn new(tag: &str) -> TempDir {
            let mut path = std::env::temp_dir();
            let nanos = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            path.push(format!(
                "rk_syslog-{tag}-{nanos}-{:?}",
                std::thread::current().id()
            ));
            fs::create_dir_all(&path).unwrap();
            TempDir(path)
        }
        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn limits(max: u64, segment: u64, policy: SpoolPolicy) -> SpoolLimits {
        SpoolLimits {
            max_bytes: max,
            segment_bytes: segment,
            policy,
        }
    }

    #[test]
    fn keeps_records_in_the_order_they_were_appended() {
        let dir = TempDir::new("fifo");
        let mut spool =
            Spool::open(dir.path(), limits(64 * 1024, 4096, SpoolPolicy::Reject)).unwrap();
        for i in 0..500 {
            spool.append(format!("record {i}").as_bytes()).unwrap();
        }
        for i in 0..500 {
            let got = spool.peek().unwrap().expect("record must be there");
            assert_eq!(got, format!("record {i}").as_bytes());
            spool.advance(got.len()).unwrap();
        }
        assert!(spool.peek().unwrap().is_none());
    }

    #[test]
    fn drop_oldest_holds_the_bound_on_disk_and_counts_what_it_lost() {
        let dir = TempDir::new("bound");
        // 16 KiB bound in 4 KiB segments, then write ~100 KiB through it.
        let mut spool = Spool::open(
            dir.path(),
            limits(16 * 1024, 4 * 1024, SpoolPolicy::DropOldest),
        )
        .unwrap();

        let payload = vec![b'x'; 200];
        for _ in 0..500 {
            spool.append(&payload).unwrap();
            spool.flush().unwrap();
            assert!(
                spool.bytes_on_disk() <= 16 * 1024,
                "spool grew to {} bytes, past its 16384-byte bound",
                spool.bytes_on_disk()
            );
        }
        let stats = spool.stats();
        assert!(
            stats.dropped_records > 0,
            "records were discarded but nothing was counted"
        );
        assert!(stats.dropped_segments > 0);
        assert!(spool.bytes_on_disk() <= 16 * 1024);
    }

    #[test]
    fn reject_holds_the_bound_and_loses_nothing() {
        let dir = TempDir::new("reject");
        let mut spool =
            Spool::open(dir.path(), limits(16 * 1024, 4 * 1024, SpoolPolicy::Reject)).unwrap();
        let payload = vec![b'y'; 200];

        let mut accepted = 0;
        let mut refused = 0;
        for _ in 0..500 {
            match spool.append(&payload) {
                Ok(()) => accepted += 1,
                Err(failure) => {
                    assert_eq!(failure.status, Status::SpoolFull);
                    assert!(failure.detail.contains("not accepted"));
                    refused += 1;
                }
            }
        }
        spool.flush().unwrap();
        assert!(accepted > 0 && refused > 0, "{accepted} in, {refused} out");
        assert!(spool.bytes_on_disk() <= 16 * 1024);
        assert_eq!(
            spool.stats().dropped_records,
            0,
            "the reject rule must never discard a record it accepted"
        );

        // Everything accepted is still readable, in order.
        let mut read = 0;
        while let Some(got) = spool.peek().unwrap() {
            assert_eq!(got, payload);
            spool.advance(got.len()).unwrap();
            read += 1;
        }
        assert_eq!(read, accepted);
    }

    #[test]
    fn a_record_larger_than_the_whole_bound_is_refused_under_either_rule() {
        for policy in [SpoolPolicy::DropOldest, SpoolPolicy::Reject] {
            let dir = TempDir::new("huge");
            let mut spool = Spool::open(dir.path(), limits(8192, 4096, policy)).unwrap();
            let failure = spool.append(&vec![b'z'; 9000]).unwrap_err();
            assert_eq!(failure.status, Status::SpoolFull);
            assert!(failure.detail.contains("cannot fit"));
        }
    }

    #[test]
    fn records_survive_the_process_going_away() {
        let dir = TempDir::new("restart");
        {
            let mut spool =
                Spool::open(dir.path(), limits(64 * 1024, 4096, SpoolPolicy::Reject)).unwrap();
            for i in 0..50 {
                spool.append(format!("before {i}").as_bytes()).unwrap();
            }
            spool.flush().unwrap();
            // Read and acknowledge ten, as a worker would.
            for _ in 0..10 {
                let got = spool.peek().unwrap().unwrap();
                spool.advance(got.len()).unwrap();
            }
        } // dropped, as a crash would drop it

        let mut spool =
            Spool::open(dir.path(), limits(64 * 1024, 4096, SpoolPolicy::Reject)).unwrap();
        // Restart resumes at the eleventh, not the first: the cursor is on
        // disk. Records already sent are not sent again.
        let got = spool.peek().unwrap().unwrap();
        assert_eq!(got, b"before 10");
        let mut count = 0;
        while let Some(record) = spool.peek().unwrap() {
            spool.advance(record.len()).unwrap();
            count += 1;
        }
        assert_eq!(count, 40);
    }

    #[test]
    fn a_torn_tail_is_truncated_and_counted_rather_than_read_as_a_record() {
        let dir = TempDir::new("torn");
        {
            let mut spool =
                Spool::open(dir.path(), limits(64 * 1024, 4096, SpoolPolicy::Reject)).unwrap();
            spool.append(b"whole record").unwrap();
            spool.flush().unwrap();
        }
        // Simulate a crash between the length prefix and the payload.
        let segment = Spool::segment_path(dir.path(), 1);
        let mut file = OpenOptions::new().append(true).open(&segment).unwrap();
        file.write_all(&999u32.to_le_bytes()).unwrap();
        file.write_all(b"half").unwrap();
        drop(file);

        let mut spool =
            Spool::open(dir.path(), limits(64 * 1024, 4096, SpoolPolicy::Reject)).unwrap();
        assert_eq!(spool.stats().torn_records, 1);
        let got = spool.peek().unwrap().unwrap();
        assert_eq!(got, b"whole record");
        spool.advance(got.len()).unwrap();
        assert!(spool.peek().unwrap().is_none());
    }

    #[test]
    fn a_bound_smaller_than_a_segment_is_refused_at_open() {
        let dir = TempDir::new("cfg");
        let failure = Spool::open(dir.path(), limits(1024, 4096, SpoolPolicy::Reject)).unwrap_err();
        assert_eq!(failure.status, Status::InvalidConfigValue);
    }

    #[test]
    fn delivered_segments_are_deleted_so_the_spool_does_not_grow_forever() {
        let dir = TempDir::new("drain");
        let mut spool =
            Spool::open(dir.path(), limits(1024 * 1024, 4096, SpoolPolicy::Reject)).unwrap();
        for i in 0..2000 {
            spool.append(format!("record {i:06}").as_bytes()).unwrap();
        }
        spool.flush().unwrap();
        let peak = spool.bytes_on_disk();
        assert!(peak > 16 * 1024, "test needs several segments, got {peak}");

        while let Some(got) = spool.peek().unwrap() {
            spool.advance(got.len()).unwrap();
        }
        assert!(
            spool.bytes_on_disk() < peak / 2,
            "sent segments were not reclaimed: {} of {peak} bytes left",
            spool.bytes_on_disk()
        );
    }
}
