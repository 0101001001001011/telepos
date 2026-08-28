/// A strict DER reader, only as wide as reading an X.509 certificate needs.
///
/// Strict is the whole point. BER lets one value be written several ways —
/// indefinite lengths, padded lengths, a boolean that is "true" in more than
/// one spelling — and every one of those is a place where two parsers disagree
/// about what a certificate says. DER admits exactly one encoding per value,
/// so this reader refuses everything else instead of guessing:
///
/// * definite lengths only, encoded in the fewest bytes that fit;
/// * low tag numbers only, since X.509 has no tag above 30;
/// * a boolean is `0x00` or `0xFF` and nothing else;
/// * every length is checked against the end of the enclosing value before a
///   single byte is read, so a truncated certificate is a refusal rather than
///   a range error escaping from somewhere deep.
///
/// It is not exported. A caller wants a certificate, not a tag.
library;

import 'dart:typed_data';

/// Raised inside this file and caught at the edge of the certificate parser,
/// which turns it into a value. It never leaves the library.
class DerException implements Exception {
  DerException(this.message);

  /// What was wrong, in words.
  final String message;

  @override
  String toString() => message;
}

/// The universal ASN.1 tags this reader knows by name.
abstract final class DerTag {
  static const int boolean = 0x01;
  static const int integer = 0x02;
  static const int bitString = 0x03;
  static const int octetString = 0x04;
  static const int objectIdentifier = 0x06;
  static const int utf8String = 0x0c;
  static const int printableString = 0x13;
  static const int ia5String = 0x16;
  static const int utcTime = 0x17;
  static const int generalizedTime = 0x18;
  static const int sequence = 0x30;
  static const int set = 0x31;
}

/// One tag-length-value, with its content still in the original buffer.
class DerValue {
  DerValue(this.bytes, this.tag, this.start, this.end, this.headerStart);

  /// The buffer the value lives in; nothing is copied until asked for.
  final Uint8List bytes;

  /// The whole first tag byte: class, constructed bit and number together.
  final int tag;

  /// Where the content begins.
  final int start;

  /// One past the last content byte.
  final int end;

  /// Where the tag byte itself is, so a value can be re-emitted verbatim.
  final int headerStart;

  /// The number of content bytes.
  int get length => end - start;

  /// Whether the constructed bit is set.
  bool get isConstructed => tag & 0x20 != 0;

  /// The tag class: 0 universal, 1 application, 2 context, 3 private.
  int get tagClass => (tag & 0xc0) >> 6;

  /// The tag number, for context-specific tags such as `[0]`.
  int get tagNumber => tag & 0x1f;

  /// The content, as a view over the original buffer.
  Uint8List get content => Uint8List.sublistView(bytes, start, end);

  /// The whole value including its header, as a view — the form a signature
  /// or a byte-for-byte comparison is taken over.
  Uint8List get encoded => Uint8List.sublistView(bytes, headerStart, end);

  /// A reader over this value's content, for a constructed value.
  DerReader get children {
    if (!isConstructed) {
      throw DerException(
        'expected a constructed value, tag 0x${tag.toRadixString(16)} is '
        'primitive',
      );
    }
    return DerReader(bytes, start, end);
  }
}

/// Walks a sequence of DER values inside one buffer window.
class DerReader {
  DerReader(this.bytes, this.offset, this.end);

  /// A reader over a whole buffer.
  factory DerReader.over(Uint8List bytes) =>
      DerReader(bytes, 0, bytes.lengthInBytes);

  /// The buffer.
  final Uint8List bytes;

  /// Where the next value begins; moves as values are read.
  int offset;

  /// One past the last byte this reader may touch.
  final int end;

  /// Whether every byte in the window has been consumed.
  bool get isEmpty => offset >= end;

  /// Reads the next value, whatever its tag.
  DerValue read() {
    final headerStart = offset;
    if (offset >= end) throw DerException('ran off the end looking for a tag');
    final tag = bytes[offset++];
    if (tag & 0x1f == 0x1f) {
      throw DerException(
        'high tag number form at offset ${offset - 1}; X.509 has no tag '
        'above 30',
      );
    }
    if (offset >= end) throw DerException('a tag with no length byte');
    final first = bytes[offset++];
    int length;
    if (first < 0x80) {
      length = first;
    } else if (first == 0x80) {
      throw DerException(
        'indefinite length at offset ${offset - 1}; that is BER, not DER',
      );
    } else if (first == 0xff) {
      throw DerException('reserved length byte 0xFF at offset ${offset - 1}');
    } else {
      final count = first & 0x7f;
      if (count > 4) {
        throw DerException(
          'a length of $count bytes is longer than any value '
          'this reader will accept',
        );
      }
      if (offset + count > end) {
        throw DerException('a length field that runs past the end');
      }
      if (bytes[offset] == 0x00) {
        throw DerException(
          'a length padded with a leading zero at offset $offset; DER encodes '
          'a length in the fewest bytes that fit',
        );
      }
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | bytes[offset++];
      }
      if (length < 0x80) {
        throw DerException(
          'the long form was used for length $length, which fits in the short '
          'form',
        );
      }
    }
    if (offset + length > end) {
      throw DerException(
        'a value of $length bytes at offset $offset runs past the end of the '
        'enclosing value',
      );
    }
    final start = offset;
    offset += length;
    return DerValue(bytes, tag, start, offset, headerStart);
  }

  /// Reads the next value and insists on [tag].
  DerValue readTagged(int tag, String what) {
    final value = read();
    if (value.tag != tag) {
      throw DerException(
        'expected $what (tag 0x${tag.toRadixString(16).padLeft(2, '0')}), '
        'found tag 0x${value.tag.toRadixString(16).padLeft(2, '0')}',
      );
    }
    return value;
  }

  /// Reads the next value only if it carries [tag], leaving the reader
  /// untouched otherwise.
  DerValue? readOptional(int tag) {
    if (isEmpty) return null;
    final mark = offset;
    final value = read();
    if (value.tag == tag) return value;
    offset = mark;
    return null;
  }

  /// Insists there is nothing left, which is how trailing rubbish after a
  /// certificate is caught rather than ignored.
  void expectEnd(String what) {
    if (!isEmpty) {
      throw DerException('${end - offset} unexpected bytes after $what');
    }
  }
}

/// Reads an INTEGER as a signed big integer, as DER writes it: two's
/// complement, big-endian, in the fewest bytes.
BigInt derInteger(DerValue value) {
  if (value.tag != DerTag.integer) {
    throw DerException('expected an INTEGER');
  }
  if (value.length == 0) throw DerException('an INTEGER with no bytes');
  final b = value.bytes;
  if (value.length > 1) {
    final first = b[value.start];
    final second = b[value.start + 1];
    if ((first == 0x00 && second & 0x80 == 0) ||
        (first == 0xff && second & 0x80 != 0)) {
      throw DerException('an INTEGER padded with a redundant leading byte');
    }
  }
  final negative = b[value.start] & 0x80 != 0;
  var result = BigInt.zero;
  for (var i = value.start; i < value.end; i++) {
    result = (result << 8) | BigInt.from(b[i]);
  }
  if (negative) {
    result -= BigInt.one << (8 * value.length);
  }
  return result;
}

/// Reads a BOOLEAN. DER allows exactly two encodings, so this rejects the
/// third and the fourth.
bool derBoolean(DerValue value) {
  if (value.tag != DerTag.boolean) throw DerException('expected a BOOLEAN');
  if (value.length != 1) {
    throw DerException('a BOOLEAN of ${value.length} bytes');
  }
  final b = value.bytes[value.start];
  if (b == 0x00) return false;
  if (b == 0xff) return true;
  throw DerException(
    'a BOOLEAN encoded as 0x${b.toRadixString(16).padLeft(2, '0')}; DER writes '
    'true as 0xFF and nothing else',
  );
}

/// Reads an OBJECT IDENTIFIER into its dotted form.
String derObjectIdentifier(DerValue value) {
  if (value.tag != DerTag.objectIdentifier) {
    throw DerException('expected an OBJECT IDENTIFIER');
  }
  if (value.length == 0) throw DerException('an OID with no bytes');
  final b = value.bytes;
  final out = StringBuffer();
  final first = b[value.start];
  // The first two arcs share a byte: 40 * first + second, capped so that arc
  // 2 can run past 39.
  final arc1 = first ~/ 40 > 2 ? 2 : first ~/ 40;
  out.write('$arc1.${first - arc1 * 40}');
  var current = BigInt.zero;
  var started = false;
  for (var i = value.start + 1; i < value.end; i++) {
    final byte = b[i];
    if (!started && byte == 0x80) {
      throw DerException('an OID arc padded with a leading 0x80');
    }
    started = true;
    current = (current << 7) | BigInt.from(byte & 0x7f);
    if (byte & 0x80 == 0) {
      out.write('.$current');
      current = BigInt.zero;
      started = false;
    }
  }
  if (started) throw DerException('an OID ending mid-arc');
  return out.toString();
}

/// Reads a BIT STRING into its bytes and the count of unused trailing bits.
({Uint8List bits, int unusedBits}) derBitString(DerValue value) {
  if (value.tag != DerTag.bitString) {
    throw DerException('expected a BIT STRING');
  }
  if (value.length == 0) throw DerException('a BIT STRING with no bytes');
  final unused = value.bytes[value.start];
  if (unused > 7) throw DerException('a BIT STRING with $unused unused bits');
  if (unused != 0 && value.length == 1) {
    throw DerException('an empty BIT STRING claiming $unused unused bits');
  }
  return (
    bits: Uint8List.sublistView(value.bytes, value.start + 1, value.end),
    unusedBits: unused,
  );
}

/// Reads an IA5String, which is ASCII and must actually be ASCII.
String derIa5String(DerValue value) {
  if (value.length == 0) return '';
  final b = value.bytes;
  final out = StringBuffer();
  for (var i = value.start; i < value.end; i++) {
    if (b[i] > 0x7f) {
      throw DerException('a byte above 0x7F inside an IA5String');
    }
    out.writeCharCode(b[i]);
  }
  return out.toString();
}

/// Reads a UTCTime or a GeneralizedTime as UTC.
///
/// RFC 5280 pins both: seconds are always present, the zone is always `Z`,
/// and a two-digit year below 50 means the 2000s. Fractional seconds and
/// local-time offsets are refused rather than interpreted.
DateTime derTime(DerValue value) {
  final text = derIa5String(value);
  switch (value.tag) {
    case DerTag.utcTime:
      if (text.length != 13 || !text.endsWith('Z')) {
        throw DerException(
          'a UTCTime of "$text"; RFC 5280 requires YYMMDDHHMMSSZ',
        );
      }
      final yy = _digits(text, 0, 2, 'year');
      final year = yy >= 50 ? 1900 + yy : 2000 + yy;
      return _assemble(year, text, 2);
    case DerTag.generalizedTime:
      if (text.length != 15 || !text.endsWith('Z')) {
        throw DerException(
          'a GeneralizedTime of "$text"; RFC 5280 requires YYYYMMDDHHMMSSZ',
        );
      }
      return _assemble(_digits(text, 0, 4, 'year'), text, 4);
    default:
      throw DerException(
        'expected a time, found tag '
        '0x${value.tag.toRadixString(16).padLeft(2, '0')}',
      );
  }
}

DateTime _assemble(int year, String text, int at) {
  final month = _digits(text, at, 2, 'month');
  final day = _digits(text, at + 2, 2, 'day');
  final hour = _digits(text, at + 4, 2, 'hour');
  final minute = _digits(text, at + 6, 2, 'minute');
  final second = _digits(text, at + 8, 2, 'second');
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw DerException('a time of "$text" is not a date');
  }
  if (hour > 23 || minute > 59 || second > 60) {
    throw DerException('a time of "$text" is not a time of day');
  }
  return DateTime.utc(year, month, day, hour, minute, second);
}

int _digits(String text, int at, int count, String what) {
  var result = 0;
  for (var i = at; i < at + count; i++) {
    final c = text.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) {
      throw DerException('a non-digit in the $what of "$text"');
    }
    result = result * 10 + (c - 0x30);
  }
  return result;
}
