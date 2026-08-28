//! Domain names on the wire, and the two things that make them awkward.
//!
//! **Compression pointers.** A name may end in a two-byte pointer to an
//! earlier offset in the same message, and a querier is free to use them —
//! many do. Reading therefore has to follow them, and following them has to be
//! bounded: a message whose pointer points at itself is the cheapest hostile
//! datagram there is, and this socket is open to the whole segment. The budget
//! below is what stops it spinning.
//!
//! **Case.** RFC 6762 §16 says names are compared case-insensitively, and
//! Avahi does not preserve the case it was asked with. A responder that
//! compared with `==` answers some resolvers and not others, which looks like
//! a network fault. [`Name::eq_ignore_case`] is the only comparison used.

use std::fmt;

/// The maximum a single label may be, from RFC 1035 §2.3.4.
pub const MAX_LABEL: usize = 63;

/// The maximum an encoded name may be, from RFC 1035 §2.3.4.
pub const MAX_NAME: usize = 255;

/// How many compression pointers one name may follow before the message is
/// treated as hostile. RFC 1035 sets no limit; this one does.
const MAX_JUMPS: usize = 16;

/// A domain name, held as its labels.
///
/// Labels are stored as raw bytes rather than as `String`: a label is defined
/// as octets, and DNS-SD instance names legitimately carry UTF-8 that is not
/// ASCII (RFC 6763 §4.1.1 — "Cafè" is a valid instance name). Turning them
/// into `String` at parse time would mean rejecting a name we are able to
/// answer.
#[derive(Clone, PartialEq, Eq, Hash, Default)]
pub struct Name {
    labels: Vec<Vec<u8>>,
}

impl Name {
    /// Builds a name from its labels. Empty labels are dropped, which is what
    /// makes a trailing dot harmless.
    pub fn from_labels(labels: Vec<Vec<u8>>) -> Self {
        Name {
            labels: labels.into_iter().filter(|l| !l.is_empty()).collect(),
        }
    }

    /// Parses a textual name. Dots separate labels; `\.` is a literal dot,
    /// which DNS-SD instance names are allowed to contain (RFC 6763 §4.3) and
    /// which a shop that named a till "Kassa 1.2" will produce.
    pub fn parse(text: &str) -> Result<Self, NameError> {
        let bytes = text.as_bytes();
        let mut labels = Vec::new();
        let mut current = Vec::new();
        let mut i = 0;
        while i < bytes.len() {
            match bytes[i] {
                b'\\' if i + 1 < bytes.len() => {
                    current.push(bytes[i + 1]);
                    i += 2;
                }
                b'.' => {
                    if !current.is_empty() {
                        labels.push(std::mem::take(&mut current));
                    }
                    i += 1;
                }
                b => {
                    current.push(b);
                    i += 1;
                }
            }
        }
        if !current.is_empty() {
            labels.push(current);
        }
        for label in &labels {
            if label.len() > MAX_LABEL {
                return Err(NameError::LabelTooLong(label.len()));
            }
        }
        let name = Name { labels };
        if name.encoded_len() > MAX_NAME {
            return Err(NameError::NameTooLong(name.encoded_len()));
        }
        Ok(name)
    }

    /// The labels, in order.
    pub fn labels(&self) -> &[Vec<u8>] {
        &self.labels
    }

    /// How many bytes this name takes with no compression.
    pub fn encoded_len(&self) -> usize {
        self.labels.iter().map(|l| l.len() + 1).sum::<usize>() + 1
    }

    /// Whether this is the root — no labels at all.
    pub fn is_root(&self) -> bool {
        self.labels.is_empty()
    }

    /// Case-insensitive equality, which is the only kind DNS has (RFC 6762
    /// §16). Using `==` here instead was the defect this method exists to make
    /// impossible to write.
    pub fn eq_ignore_case(&self, other: &Name) -> bool {
        self.labels.len() == other.labels.len()
            && self
                .labels
                .iter()
                .zip(other.labels.iter())
                .all(|(a, b)| a.eq_ignore_ascii_case(b))
    }

    /// Whether `self` ends with `suffix`, case-insensitively. Used to tell an
    /// instance of a service type (`till-3._telepos._tcp.local`) from the type
    /// itself (`_telepos._tcp.local`).
    pub fn ends_with(&self, suffix: &Name) -> bool {
        if suffix.labels.len() > self.labels.len() {
            return false;
        }
        let offset = self.labels.len() - suffix.labels.len();
        self.labels[offset..]
            .iter()
            .zip(suffix.labels.iter())
            .all(|(a, b)| a.eq_ignore_ascii_case(b))
    }

    /// A new name with `label` in front. `till-3` prepended to
    /// `_telepos._tcp.local` is how a DNS-SD instance name is built.
    pub fn prepend(&self, label: &[u8]) -> Name {
        let mut labels = Vec::with_capacity(self.labels.len() + 1);
        labels.push(label.to_vec());
        labels.extend(self.labels.iter().cloned());
        Name { labels }
    }

    /// Everything after the first label, or the root when there is nothing.
    pub fn without_first_label(&self) -> Name {
        if self.labels.is_empty() {
            return Name::default();
        }
        Name {
            labels: self.labels[1..].to_vec(),
        }
    }

    /// Writes the name with no compression.
    ///
    /// Pointers are read but never written. They are optional in a response,
    /// omitting them costs a few dozen bytes in a datagram with a kilobyte of
    /// room, and writing them would mean tracking offsets across five record
    /// types for a saving no shop network can measure.
    pub fn encode(&self, out: &mut Vec<u8>) {
        for label in &self.labels {
            out.push(label.len() as u8);
            out.extend_from_slice(label);
        }
        out.push(0);
    }

    /// Reads a name starting at `start`, following compression pointers.
    ///
    /// Returns the name and the offset reading continues at — which is past
    /// the pointer, not past whatever the pointer led to.
    pub fn decode(message: &[u8], start: usize) -> Result<(Name, usize), NameError> {
        let mut labels: Vec<Vec<u8>> = Vec::new();
        let mut offset = start;
        let mut next: Option<usize> = None;
        let mut jumps = 0usize;
        let mut total = 0usize;

        loop {
            if offset >= message.len() {
                return Err(NameError::Truncated);
            }
            let length = message[offset];
            if length == 0 {
                return Ok((Name { labels }, next.unwrap_or(offset + 1)));
            }
            if length & 0xc0 == 0xc0 {
                if offset + 1 >= message.len() {
                    return Err(NameError::Truncated);
                }
                jumps += 1;
                if jumps > MAX_JUMPS {
                    return Err(NameError::PointerLoop);
                }
                let target = (((length & 0x3f) as usize) << 8) | message[offset + 1] as usize;
                if next.is_none() {
                    next = Some(offset + 2);
                }
                if target >= message.len() {
                    return Err(NameError::Truncated);
                }
                // A pointer must point backwards. Forward pointers are the
                // other half of the loop this budget guards against, and they
                // are illegal by RFC 1035 §4.1.4 anyway.
                if target >= offset {
                    return Err(NameError::PointerLoop);
                }
                offset = target;
                continue;
            }
            if length as usize > MAX_LABEL {
                return Err(NameError::LabelTooLong(length as usize));
            }
            let end = offset + 1 + length as usize;
            if end > message.len() {
                return Err(NameError::Truncated);
            }
            total += length as usize + 1;
            if total > MAX_NAME {
                return Err(NameError::NameTooLong(total));
            }
            labels.push(message[offset + 1..end].to_vec());
            offset = end;
        }
    }
}

impl fmt::Display for Name {
    /// Renders the name the way a resolver prints it, escaping the dots inside
    /// a label so the text can be parsed back into the same name.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut first = true;
        for label in &self.labels {
            if !first {
                f.write_str(".")?;
            }
            first = false;
            for &byte in label {
                match byte {
                    b'.' => f.write_str("\\.")?,
                    b'\\' => f.write_str("\\\\")?,
                    0x20..=0x7e => write!(f, "{}", byte as char)?,
                    other => write!(f, "\\{other:03}")?,
                }
            }
        }
        Ok(())
    }
}

impl fmt::Debug for Name {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Name({self})")
    }
}

/// Why a name could not be read or built.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NameError {
    /// A label longer than 63 octets.
    LabelTooLong(usize),
    /// An encoded name longer than 255 octets.
    NameTooLong(usize),
    /// The message ended in the middle of a name.
    Truncated,
    /// Compression pointers that do not terminate. Deliberately distinct from
    /// [`NameError::Truncated`]: one is a clipped datagram, the other is a
    /// datagram built to make a responder spin.
    PointerLoop,
}

impl fmt::Display for NameError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            NameError::LabelTooLong(n) => write!(f, "a label of {n} octets, over the 63 allowed"),
            NameError::NameTooLong(n) => write!(f, "a name of {n} octets, over the 255 allowed"),
            NameError::Truncated => write!(f, "the message ended inside a name"),
            NameError::PointerLoop => write!(f, "compression pointers that do not terminate"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn n(text: &str) -> Name {
        Name::parse(text).expect("test name parses")
    }

    #[test]
    fn a_name_survives_a_round_trip() {
        let name = n("till-3._telepos._tcp.local");
        let mut buffer = Vec::new();
        name.encode(&mut buffer);
        let (read, next) = Name::decode(&buffer, 0).expect("decodes");
        assert!(read.eq_ignore_case(&name));
        assert_eq!(next, buffer.len());
        assert_eq!(read.to_string(), "till-3._telepos._tcp.local");
    }

    #[test]
    fn a_dot_inside_a_label_survives_the_round_trip() {
        // RFC 6763 §4.3: an instance name may contain a dot, and it is escaped
        // in text and length-prefixed on the wire. A till called "Kassa 1.2" is
        // ordinary, and splitting it into two labels would announce a service
        // nobody can resolve.
        let name = n("Kassa 1\\.2._telepos._tcp.local");
        assert_eq!(name.labels()[0], b"Kassa 1.2");
        let mut buffer = Vec::new();
        name.encode(&mut buffer);
        let (read, _) = Name::decode(&buffer, 0).expect("decodes");
        assert_eq!(read.labels()[0], b"Kassa 1.2");
        assert_eq!(read.to_string(), "Kassa 1\\.2._telepos._tcp.local");
    }

    #[test]
    fn comparison_ignores_case_because_dns_does() {
        assert!(n("Till-3.local").eq_ignore_case(&n("till-3.LOCAL")));
        assert!(!n("till-3.local").eq_ignore_case(&n("till-4.local")));
    }

    #[test]
    fn a_pointer_is_followed_and_reading_continues_past_the_pointer() {
        // "local" at offset 0, then "till-3" + a pointer back to it.
        let mut message = Vec::new();
        n("local").encode(&mut message);
        let pointer_at = message.len();
        message.push(6);
        message.extend_from_slice(b"till-3");
        message.push(0xc0);
        message.push(0x00);
        message.push(0xaa); // a byte after the name, to prove `next` is right

        let (name, next) = Name::decode(&message, pointer_at).expect("decodes");
        assert_eq!(name.to_string(), "till-3.local");
        assert_eq!(next, message.len() - 1);
    }

    #[test]
    fn a_pointer_to_itself_is_refused_rather_than_followed() {
        // The cheapest hostile datagram there is. Without the budget this loops
        // forever inside a responder that anything on the segment can reach.
        let message = vec![0xc0, 0x00];
        assert_eq!(Name::decode(&message, 0), Err(NameError::PointerLoop));
    }

    #[test]
    fn a_forward_pointer_is_refused() {
        let message = vec![0xc0, 0x04, 0x00, 0x00, 0x00];
        assert_eq!(Name::decode(&message, 0), Err(NameError::PointerLoop));
    }

    #[test]
    fn a_truncated_name_is_an_error_and_not_a_panic() {
        assert_eq!(Name::decode(&[5, b'a', b'b'], 0), Err(NameError::Truncated));
        assert_eq!(Name::decode(&[], 0), Err(NameError::Truncated));
    }

    #[test]
    fn an_over_long_label_is_refused_on_the_way_in_and_out() {
        let long = "x".repeat(64);
        assert_eq!(Name::parse(&long), Err(NameError::LabelTooLong(64)));
    }

    #[test]
    fn ends_with_tells_an_instance_from_its_type() {
        let instance = n("till-3._telepos._tcp.local");
        let service = n("_telepos._tcp.local");
        assert!(instance.ends_with(&service));
        assert!(!service.ends_with(&instance));
        assert!(!instance.ends_with(&n("_other._tcp.local")));
    }

    #[test]
    fn prepend_builds_the_instance_name() {
        let built = n("_telepos._tcp.local").prepend(b"till-3");
        assert!(built.eq_ignore_case(&n("till-3._telepos._tcp.local")));
    }
}
