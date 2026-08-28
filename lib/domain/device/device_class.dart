/// The device classes this system knows about, independent of any model.
///
/// A class states what a device *does*; a [DeviceProfile] states how to talk
/// to one particular model that does it. See docs/system-architecture.md,
/// section 8, "Класс устройства, а не модель".
library;

enum DeviceClass {
  receiptPrinter,
  labelPrinter,
  scanner,
  scale,
  cashDrawer,
  customerDisplay,
  paymentTerminal,
}

/// The wire protocols a profile can declare. De-facto standards named in
/// docs/system-architecture.md, section 8: ESC/POS for receipt printers,
/// ZPL/EPL for label printers. `hidKeyboard` covers barcode scanners that
/// present themselves as a keyboard, which is most of them; `cameraScan`
/// covers a scanner that is software reading the host's camera, which does
/// not "talk HID" at all; `serialScanner` covers the third connection kind
/// this product has always supported — `ScannerMode.serialPort` in
/// `lib/presentation/common/mixins/barcode_scanner_mixin.dart` — a scanner
/// that speaks over a COM port instead of presenting as a keyboard or living
/// in software.
enum DeviceProtocol {
  escPos,
  zpl,
  epl,
  casScale,
  serialDisplay,
  kaspiPos,
  hidKeyboard,
  cameraScan,
  serialScanner,
}
