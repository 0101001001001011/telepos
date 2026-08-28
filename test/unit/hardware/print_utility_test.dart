import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/printer/print_utility.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// Records exactly what `PrintUtility.testPrint` sends, so the byte sequence
/// itself can be asserted on — no serial port, socket, or OS spooler
/// touched.
class _RecordingPrinterManager implements PrinterManager {
  Uint8List? lastReceipt;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<PrinterConnectionResult> connect() async {
    _connected = true;
    return PrinterConnectionResult.ok(
      const PrinterInfo(name: 'Recorder', address: 'test://recorder'),
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<PrinterStatus> getStatus() async => PrinterStatus.ok;

  @override
  Future<PrintResult> writeRaw(Uint8List data) async =>
      PrintResult.ok(bytesSent: data.length);

  @override
  Future<PrintResult> printText(String text) async =>
      PrintResult.ok(bytesSent: text.length);

  @override
  Future<PrintResult> printReceipt(Uint8List receiptData) async {
    lastReceipt = receiptData;
    return PrintResult.ok(bytesSent: receiptData.length);
  }

  @override
  Future<void> openCashDrawer() async {}

  @override
  Future<void> cutPaper() async {}

  @override
  Future<void> feedLines(int lines) async {}

  @override
  Future<void> initialize() async {}
}

/// Finds the first index of [needle] as a contiguous run inside [haystack],
/// or -1.
int _indexOfSequence(List<int> haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}

void main() {
  group('PrintUtility.testPrint', () {
    test(
      'the reset command is immediately followed by the CP866 code-page '
      'select — a bare reset with no reselect silently undoes '
      "initialize()'s code page and turns the Cyrillic line into mojibake",
      () async {
        final printer = _RecordingPrinterManager();

        final result = await PrintUtility.testPrint(printer);

        expect(result.success, isTrue);
        final sent = printer.lastReceipt;
        expect(sent, isNotNull);

        // ESC @ (reset) — 0x1B, 0x40 — must appear, and every time it does,
        // ESC t 17 (select CP866) must follow it immediately. A regression
        // to a bare `[0x1B, 0x40]` with nothing after it would make this
        // fail: the reset command would be found, but not at a position
        // whose next three bytes are the code-page select.
        final resetIndex = _indexOfSequence(sent!, const [0x1B, 0x40]);
        expect(
          resetIndex,
          isNonNegative,
          reason: 'the test page must reset the printer at least once',
        );
        expect(
          sent.sublist(resetIndex, resetIndex + 5),
          const [0x1B, 0x40, 0x1B, 0x74, 17],
          reason:
              'reset (ESC @) must be immediately followed by CP866 select '
              '(ESC t 17) — matching EscPosCommands.init/ReceiptBuilder.init '
              '— otherwise the Cyrillic bytes that follow render in whatever '
              "code page the printer's own reset default is, not CP866",
        );

        // The Cyrillic test line itself must appear somewhere after the
        // reset+reselect, CP866-encoded (е.g. 'Т' = 0x54 is ASCII, but the
        // Cyrillic letters map into the 0x80-0xFF range — this just checks
        // the reselect happens before any high-byte content is written).
        final firstHighByteIndex = sent.indexWhere(
          (b) => b >= 0x80,
          resetIndex,
        );
        expect(
          firstHighByteIndex,
          greaterThan(resetIndex + 4),
          reason:
              'no CP866-encoded (high) byte may be written before the '
              'reselect that follows the reset',
        );
      },
    );
  });
}
