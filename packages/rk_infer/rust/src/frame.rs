//! Frame buffers, and exactly who frees them.
//!
//! # И146, said in one paragraph
//!
//! The pixel buffer is one `Vec<u8>` allocated by [`Frame::new`] and dropped
//! by [`Frame::into_freed`]. Rust allocates it; Rust frees it; the Dart side
//! neither allocates nor frees frame pixels. It receives a write pointer into
//! the buffer, copies decoded pixels in, and drops the view. A run *borrows*
//! the frame -- ownership never moves -- so there is no state in which two
//! sides both believe someone else will free it.
//!
//! This matters more here than anywhere else in the package because of the
//! size. An uncompressed 1920x1080 RGB frame is 6.2 MB. At a handful of frames
//! per second on the floor hardware this product actually ships to -- modest
//! x86 and a Raspberry Pi 5 -- leaving that to a garbage collector is the
//! difference between running and swapping.
//!
//! # Why there is no reader
//!
//! There is no function on `Frame` that returns pixels. The write pointer
//! exists so a frame can be filled, which is the only direction pixels travel.
//! Section 21 of the architecture is enforced by the absence of the other
//! direction, not by a rule someone has to remember.

use std::sync::atomic::{AtomicBool, Ordering};

use crate::manifest::PixelFormat;
use crate::status::{Failure, Outcome, Status};

pub struct Frame {
    format: PixelFormat,
    width: u32,
    height: u32,
    pixels: Vec<u8>,
    /// Set while a run holds this frame. Freeing during a borrow is refused
    /// rather than pulling memory out from under the engine.
    borrowed: AtomicBool,
}

impl Frame {
    pub fn new(width: u32, height: u32, format: PixelFormat) -> Outcome<Frame> {
        if width == 0 || height == 0 {
            return Err(Failure::new(
                Status::InvalidArgument,
                format!(
                    "frame dimensions must be non-zero, got {}x{}",
                    width, height
                ),
            ));
        }

        // Overflow here would allocate a buffer smaller than the caller
        // believes and then be written past. Checked, not assumed.
        let bytes = (width as usize)
            .checked_mul(height as usize)
            .and_then(|px| px.checked_mul(format.bytes_per_pixel()))
            .ok_or_else(|| {
                Failure::new(
                    Status::InvalidArgument,
                    format!(
                        "{}x{} in {} overflows a size_t",
                        width,
                        height,
                        format.name()
                    ),
                )
            })?;

        Ok(Frame {
            format,
            width,
            height,
            pixels: vec![0u8; bytes],
            borrowed: AtomicBool::new(false),
        })
    }

    pub fn len(&self) -> usize {
        self.pixels.len()
    }

    pub fn is_empty(&self) -> bool {
        self.pixels.is_empty()
    }

    pub fn width(&self) -> u32 {
        self.width
    }

    pub fn height(&self) -> u32 {
        self.height
    }

    pub fn format(&self) -> PixelFormat {
        self.format
    }

    /// The writable region, for the caller to fill. Valid until the frame is
    /// freed. Not owned by the caller.
    pub fn write_ptr(&mut self) -> *mut u8 {
        self.pixels.as_mut_ptr()
    }

    /// Takes the borrow for the duration of a run. `None` if someone already
    /// holds it, which is a caller bug reported as a value.
    pub fn borrow_for_run(&self) -> Option<RunBorrow<'_>> {
        if self
            .borrowed
            .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
        {
            Some(RunBorrow { frame: self })
        } else {
            None
        }
    }

    pub fn is_borrowed(&self) -> bool {
        self.borrowed.load(Ordering::Acquire)
    }

    /// Frees the frame, or refuses because a run holds it.
    ///
    /// Taking `self` by value is the point: there is no path that frees a
    /// borrowed frame, because the only way to free is to consume, and a
    /// borrowed frame is handed back instead of consumed.
    pub fn into_freed(self) -> Result<(), (Frame, Failure)> {
        if self.is_borrowed() {
            let failure = Failure::new(
                Status::FrameInUse,
                "a run holds this frame; freeing it now would free memory the \
                 engine is reading"
                    .to_string(),
            );
            return Err((self, failure));
        }
        drop(self);
        Ok(())
    }
}

impl std::fmt::Debug for Frame {
    /// Hand-written, and the reason is section 21, not neatness.
    ///
    /// `#[derive(Debug)]` on a struct holding a `Vec<u8>` prints the pixels.
    /// One `dbg!`, one `{:?}` in a log line, one `.unwrap()` on a `Result`
    /// carrying a `Frame`, and six megabytes of a customer's image are in a
    /// file on a till. The derive is not an option here; the shape is all this
    /// prints, and `frame_debug_never_prints_pixels` keeps it that way.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Frame")
            .field("width", &self.width)
            .field("height", &self.height)
            .field("format", &self.format.name())
            .field("bytes", &self.pixels.len())
            .field("borrowed", &self.is_borrowed())
            .finish()
    }
}

/// Proof that a run holds the frame. Releases on drop, including on the panic
/// path, so a caught panic cannot leave a frame permanently unfreeable.
pub struct RunBorrow<'a> {
    frame: &'a Frame,
}

impl RunBorrow<'_> {
    pub fn pixels(&self) -> &[u8] {
        &self.frame.pixels
    }
}

impl Drop for RunBorrow<'_> {
    fn drop(&mut self) {
        self.frame.borrowed.store(false, Ordering::Release);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_frame_is_exactly_as_large_as_its_shape() {
        let cases = [
            (640u32, 384u32, PixelFormat::Rgb8, 640 * 384 * 3),
            (640, 384, PixelFormat::Rgba8, 640 * 384 * 4),
            (640, 384, PixelFormat::Gray8, 640 * 384),
            (1920, 1080, PixelFormat::Rgb8, 1920 * 1080 * 3),
        ];
        for (w, h, f, want) in cases {
            let frame = Frame::new(w, h, f).unwrap();
            assert_eq!(frame.len(), want, "{}x{} {}", w, h, f.name());
        }
    }

    #[test]
    fn a_frame_starts_zeroed_so_a_partial_fill_is_not_stale_pixels() {
        let frame = Frame::new(8, 8, PixelFormat::Rgb8).unwrap();
        let borrow = frame.borrow_for_run().unwrap();
        assert!(borrow.pixels().iter().all(|b| *b == 0));
    }

    #[test]
    fn zero_and_overflowing_shapes_are_refused_as_values() {
        assert_eq!(
            Frame::new(0, 10, PixelFormat::Rgb8).unwrap_err().status,
            Status::InvalidArgument
        );
        assert_eq!(
            Frame::new(10, 0, PixelFormat::Rgb8).unwrap_err().status,
            Status::InvalidArgument
        );
        // On a 64-bit host u32::MAX squared times 3 does not overflow usize, so
        // this asserts the allocation is at least *attempted* sanely rather
        // than the arithmetic wrapping to something small.
        let huge = Frame::new(u32::MAX, u32::MAX, PixelFormat::Rgba8);
        assert!(huge.is_err(), "an absurd shape must not silently succeed");
    }

    #[test]
    fn writing_through_the_pointer_reaches_the_buffer() {
        let mut frame = Frame::new(4, 2, PixelFormat::Gray8).unwrap();
        let len = frame.len();
        assert_eq!(len, 8);
        unsafe {
            let p = frame.write_ptr();
            for i in 0..len {
                *p.add(i) = (i as u8) + 1;
            }
        }
        let borrow = frame.borrow_for_run().unwrap();
        assert_eq!(borrow.pixels(), &[1, 2, 3, 4, 5, 6, 7, 8]);
    }

    #[test]
    fn a_frame_held_by_a_run_refuses_to_be_freed_and_survives_the_refusal() {
        let frame = Frame::new(4, 4, PixelFormat::Rgb8).unwrap();
        let borrow = frame.borrow_for_run().unwrap();

        // Second borrow while the first is live: refused.
        assert!(frame.borrow_for_run().is_none());

        drop(borrow);
        assert!(!frame.is_borrowed(), "dropping the borrow releases it");
        assert!(frame.borrow_for_run().is_some());
    }

    #[test]
    fn into_freed_hands_the_frame_back_rather_than_freeing_it_under_a_run() {
        // Model what the ABI does: a borrow taken elsewhere, then a free.
        let frame = Frame::new(4, 4, PixelFormat::Rgb8).unwrap();
        frame.borrowed.store(true, Ordering::Release);

        let (returned, failure) = frame.into_freed().unwrap_err();
        assert_eq!(failure.status, Status::FrameInUse);
        assert_eq!(returned.len(), 4 * 4 * 3, "the frame is intact, not freed");

        returned.borrowed.store(false, Ordering::Release);
        assert!(returned.into_freed().is_ok(), "and it frees once released");
    }

    #[test]
    fn frame_debug_never_prints_pixels() {
        // The attack this defends against is not malice, it is a `{:?}` in a
        // log line. Fill the frame with a pattern nothing else would produce
        // and demand it is absent from the debug output.
        let mut frame = Frame::new(64, 64, PixelFormat::Rgb8).unwrap();
        let len = frame.len();
        unsafe {
            let p = frame.write_ptr();
            for i in 0..len {
                *p.add(i) = 0xC7;
            }
        }

        let rendered = format!("{:?}", frame);
        assert!(rendered.contains("width: 64"), "{}", rendered);
        assert!(rendered.contains("bytes: 12288"), "{}", rendered);
        assert!(
            !rendered.contains("199") && !rendered.contains("c7") && !rendered.contains("C7"),
            "the debug output leaked pixel values: {}",
            rendered
        );
        assert!(
            rendered.len() < 200,
            "debug output is {} bytes; a frame's worth of pixels would be far \
             larger, so length alone catches a re-derived Debug: {}",
            rendered.len(),
            rendered
        );
    }

    #[test]
    fn a_borrow_releases_even_when_the_run_panics() {
        let frame = Frame::new(2, 2, PixelFormat::Gray8).unwrap();
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let _borrow = frame.borrow_for_run().unwrap();
            panic!("engine exploded");
        }));
        assert!(result.is_err());
        assert!(
            !frame.is_borrowed(),
            "a caught panic must not leave the frame unfreeable forever"
        );
    }
}
