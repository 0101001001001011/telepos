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

  /// Не протокол, а его **отсутствие**: прибора нет вовсе, и разговаривать
  /// не с кем.
  ///
  /// Объявлен ради двух семейств из семи, у которых нет ни адреса, ни
  /// последовательного порта, — HID-сканера и печати через спулер
  /// операционной системы. Всё остальное железо эмулируется **снаружи**
  /// продукта: сетевые приборы (чековый и этикеточный принтеры, терминал
  /// оплаты, фискальный оператор) — своим адресом в уже существующих полях
  /// настроек, приборы с COM-портом (весы, дисплей покупателя) — петлёй
  /// операционной системы (com0com/socat). Ни то ни другое не требует ни
  /// одной строки в `lib/`, и профиль с этим протоколом им не нужен.
  ///
  /// **Профиль с этим протоколом не должен доехать до магазина.** Единственный
  /// каталог, который такие профили отдаёт
  /// (`lib/emulators/emulated_device_profile_catalog.dart`), подмешивается в
  /// `service_locator.dart` за `const bool.fromEnvironment`, то есть за
  /// константой времени компиляции. Что AOT его действительно выбрасывает —
  /// **измерено**, а не предположено: `docs/internal/testing-notes.md`,
  /// раздел «Виртуальные профили и AOT».
  emulated,
}
