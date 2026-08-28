//! The hand-off between the caller and the worker.
//!
//! # The guarantee
//!
//! Submitting a record must not wait on anything the caller cannot bound. A
//! till whose collector is unreachable keeps selling at full speed, and
//! "unreachable" includes the worst case — a routable address that never
//! answers, where a connect attempt takes the operating system's timeout,
//! tens of seconds.
//!
//! So a submit does exactly two things: frame the record (pure computation)
//! and move the resulting `Vec` into this queue. The only lock it touches is
//! held across a pointer move. **No file, socket or DNS call ever happens
//! under it**, which is what makes the wait bounded by the worker's dequeue
//! rather than by the network.
//!
//! # What that costs
//!
//! A record is durable once the worker has written it to the spool, not at
//! the moment of submit. A crash loses whatever is still in this queue. The
//! window is bounded by `queue_max_records`, and a caller who needs a
//! durability point at a particular moment asks for one with `flush`, which
//! blocks that caller and nobody else.

use std::collections::VecDeque;
use std::sync::{Condvar, Mutex};
use std::time::Duration;

use crate::status::{Failure, Fallible, Status};

/// What the queue does when the worker has fallen behind.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueuePolicy {
    /// Discard the oldest waiting record and count it.
    DropOldest,
    /// Refuse the submit, so the caller learns immediately.
    Reject,
}

impl QueuePolicy {
    pub const fn name(self) -> &'static str {
        match self {
            QueuePolicy::DropOldest => "drop_oldest",
            QueuePolicy::Reject => "reject",
        }
    }

    pub fn from_name(name: &str) -> Option<QueuePolicy> {
        match name {
            "drop_oldest" => Some(QueuePolicy::DropOldest),
            "reject" => Some(QueuePolicy::Reject),
            _ => None,
        }
    }
}

#[derive(Debug, Default)]
struct Inner {
    items: VecDeque<Vec<u8>>,
    closed: bool,
    dropped: u64,
    /// True from the moment the worker takes a batch until it has written it
    /// to the spool.
    ///
    /// Without this, an empty queue is ambiguous — it means either "your
    /// records are on disk" or "the worker is holding them and has not
    /// written them yet" — and a flush that cannot tell those apart returns
    /// before the durability point it exists to provide. Found by a test that
    /// read a counter straight after a flush and saw zero.
    in_flight: bool,
}

#[derive(Debug)]
pub struct Queue {
    inner: Mutex<Inner>,
    not_empty: Condvar,
    drained: Condvar,
    capacity: usize,
    policy: QueuePolicy,
}

impl Queue {
    pub fn new(capacity: usize, policy: QueuePolicy) -> Queue {
        Queue {
            inner: Mutex::new(Inner::default()),
            not_empty: Condvar::new(),
            drained: Condvar::new(),
            capacity: capacity.max(1),
            policy,
        }
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        // A poisoned lock means a previous holder panicked. The data behind
        // it is a queue of byte vectors with no invariant to violate, and
        // refusing to log because logging once panicked is the wrong trade.
        self.inner.lock().unwrap_or_else(|e| e.into_inner())
    }

    /// Hands a framed record to the worker. Never waits on I/O.
    pub fn push(&self, record: Vec<u8>) -> Fallible<()> {
        let mut inner = self.lock();
        if inner.closed {
            return Err(Failure::new(
                Status::Closed,
                "the sink is closed; the record was not accepted".to_string(),
            ));
        }
        if inner.items.len() >= self.capacity {
            match self.policy {
                QueuePolicy::Reject => {
                    return Err(Failure::new(
                        Status::QueueFull,
                        format!(
                            "the hand-off queue holds {} records, its limit, and the \
                             rule is 'reject'; the record was not accepted",
                            self.capacity
                        ),
                    ));
                }
                QueuePolicy::DropOldest => {
                    inner.items.pop_front();
                    inner.dropped += 1;
                }
            }
        }
        inner.items.push_back(record);
        drop(inner);
        self.not_empty.notify_one();
        Ok(())
    }

    /// Takes everything waiting. Returns empty only when the queue is closed
    /// or the wait expired.
    pub fn drain_blocking(&self, timeout: Duration) -> (Vec<Vec<u8>>, bool) {
        let mut inner = self.lock();
        if inner.items.is_empty() && !inner.closed {
            let (guard, _) = self
                .not_empty
                .wait_timeout(inner, timeout)
                .unwrap_or_else(|e| e.into_inner());
            inner = guard;
        }
        let closed = inner.closed;
        let items: Vec<Vec<u8>> = std::mem::take(&mut inner.items).into_iter().collect();
        // Taken but not yet written. A flush must keep waiting.
        inner.in_flight = !items.is_empty();
        (items, closed)
    }

    /// Called by the worker once a drained batch has reached the spool.
    pub fn mark_drained(&self) {
        let mut inner = self.lock();
        inner.in_flight = false;
        drop(inner);
        self.drained.notify_all();
    }

    /// Waits until everything queued at the moment of the call has been
    /// drained by the worker. This is the one call that blocks on purpose.
    pub fn wait_drained(&self, timeout: Duration) -> Fallible<()> {
        let deadline = std::time::Instant::now() + timeout;
        let mut inner = self.lock();
        while !inner.items.is_empty() || inner.in_flight {
            let left = deadline.saturating_duration_since(std::time::Instant::now());
            if left.is_zero() {
                return Err(Failure::new(
                    Status::Timeout,
                    format!(
                        "{} records were still waiting and {} being written when the \
                         flush expired",
                        inner.items.len(),
                        if inner.in_flight {
                            "a batch was"
                        } else {
                            "none were"
                        },
                    ),
                ));
            }
            let (guard, _) = self
                .drained
                .wait_timeout(inner, left)
                .unwrap_or_else(|e| e.into_inner());
            inner = guard;
            if inner.closed {
                break;
            }
        }
        Ok(())
    }

    /// Stops accepting and wakes the worker so it can finish.
    pub fn close(&self) {
        let mut inner = self.lock();
        inner.closed = true;
        drop(inner);
        self.not_empty.notify_all();
        self.drained.notify_all();
    }

    pub fn len(&self) -> usize {
        self.lock().items.len()
    }

    pub fn is_empty(&self) -> bool {
        self.lock().items.is_empty()
    }

    pub fn dropped(&self) -> u64 {
        self.lock().dropped
    }

    pub fn take_dropped(&self) -> u64 {
        std::mem::take(&mut self.lock().dropped)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    #[test]
    fn hands_records_over_in_order() {
        let queue = Queue::new(16, QueuePolicy::Reject);
        for i in 0..5u8 {
            queue.push(vec![i]).unwrap();
        }
        let (items, _) = queue.drain_blocking(Duration::from_millis(10));
        assert_eq!(items, vec![vec![0], vec![1], vec![2], vec![3], vec![4]]);
    }

    #[test]
    fn a_full_queue_under_the_reject_rule_refuses_rather_than_waits() {
        let queue = Queue::new(2, QueuePolicy::Reject);
        queue.push(vec![1]).unwrap();
        queue.push(vec![2]).unwrap();
        let failure = queue.push(vec![3]).unwrap_err();
        assert_eq!(failure.status, Status::QueueFull);
        assert!(failure.detail.contains("not accepted"));
        assert_eq!(queue.len(), 2);
    }

    #[test]
    fn a_full_queue_under_the_drop_rule_makes_room_and_counts_the_loss() {
        let queue = Queue::new(2, QueuePolicy::DropOldest);
        queue.push(vec![1]).unwrap();
        queue.push(vec![2]).unwrap();
        queue.push(vec![3]).unwrap();
        assert_eq!(queue.dropped(), 1);
        let (items, _) = queue.drain_blocking(Duration::from_millis(10));
        assert_eq!(items, vec![vec![2], vec![3]]);
    }

    #[test]
    fn a_closed_queue_refuses_instead_of_swallowing() {
        let queue = Queue::new(4, QueuePolicy::Reject);
        queue.close();
        assert_eq!(queue.push(vec![1]).unwrap_err().status, Status::Closed);
    }

    #[test]
    fn pushing_does_not_wait_on_a_slow_consumer() {
        // The consumer sleeps for a second between drains. Pushes must not
        // notice, because nothing about a push depends on the consumer
        // beyond the capacity check.
        let queue = Arc::new(Queue::new(100_000, QueuePolicy::Reject));
        let consumer = {
            let queue = Arc::clone(&queue);
            std::thread::spawn(move || loop {
                let (items, closed) = queue.drain_blocking(Duration::from_millis(50));
                std::thread::sleep(Duration::from_millis(200));
                queue.mark_drained();
                if closed && items.is_empty() {
                    return;
                }
            })
        };
        let started = std::time::Instant::now();
        for i in 0..10_000 {
            queue.push(vec![(i % 251) as u8; 64]).unwrap();
        }
        let elapsed = started.elapsed();
        queue.close();
        consumer.join().unwrap();
        assert!(
            elapsed < Duration::from_millis(1500),
            "10000 pushes took {elapsed:?} while the consumer was asleep"
        );
    }

    #[test]
    fn flush_gives_up_rather_than_waiting_forever() {
        let queue = Queue::new(4, QueuePolicy::Reject);
        queue.push(vec![1]).unwrap();
        let failure = queue.wait_drained(Duration::from_millis(50)).unwrap_err();
        assert_eq!(failure.status, Status::Timeout);
    }

    #[test]
    fn flush_waits_for_a_batch_the_worker_already_took() {
        // The race this guards. The worker takes the batch first, so the
        // queue is empty by the time flush is called — but the records are
        // in the worker's hands, not on disk. A flush that returned here
        // would be reporting a durability point that had not happened, which
        // is the whole reason the call exists.
        let queue = Arc::new(Queue::new(64, QueuePolicy::Reject));
        queue.push(vec![1]).unwrap();

        let (taken_tx, taken_rx) = std::sync::mpsc::channel();
        let written = Arc::new(std::sync::atomic::AtomicBool::new(false));
        let worker = {
            let queue = Arc::clone(&queue);
            let written = Arc::clone(&written);
            std::thread::spawn(move || {
                let _ = queue.drain_blocking(Duration::from_millis(500));
                taken_tx.send(()).unwrap();
                // Stand in for writing to the spool.
                std::thread::sleep(Duration::from_millis(300));
                written.store(true, std::sync::atomic::Ordering::SeqCst);
                queue.mark_drained();
            })
        };

        taken_rx.recv_timeout(Duration::from_secs(2)).unwrap();
        assert_eq!(queue.len(), 0, "the worker should be holding the record");
        queue.wait_drained(Duration::from_secs(5)).unwrap();
        assert!(
            written.load(std::sync::atomic::Ordering::SeqCst),
            "flush returned before the batch it was waiting for was written"
        );
        worker.join().unwrap();
    }

    #[test]
    fn flush_returns_once_the_worker_has_taken_the_batch() {
        let queue = Arc::new(Queue::new(64, QueuePolicy::Reject));
        queue.push(vec![1]).unwrap();
        let worker = {
            let queue = Arc::clone(&queue);
            std::thread::spawn(move || {
                let _ = queue.drain_blocking(Duration::from_millis(100));
                queue.mark_drained();
            })
        };
        queue.wait_drained(Duration::from_secs(2)).unwrap();
        worker.join().unwrap();
    }
}
