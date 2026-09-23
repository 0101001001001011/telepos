/// Названия моделей устройств и подписи их параметров — для человека.
///
/// # Почему не в самом каталоге
///
/// `DeviceProfileCatalogBuiltin` живёт в слое данных и языка интерфейса не
/// знает. До этой правки он вёз готовые слова, и половина из них была
/// русской, половина английской — на экране привязки они стояли рядом в
/// одном списке: «Чековый принтер ESC/POS 80 мм» под «Label Printer ZPL
/// 104mm». На английском интерфейсе половина списка оставалась русской.
///
/// Здесь по **устойчивому идентификатору** профиля выбирается ключ словаря.
/// Идентификатор — то, что уже хранится в привязках и ездит по проводу;
/// менять его нельзя, а слово рядом с ним — можно и нужно.
///
/// # Что делать с неизвестным идентификатором
///
/// Вернуть то, что несёт сам профиль. Это не «на всякий случай»: каталог
/// расширяется, и профиль, появившийся раньше своего ключа, обязан
/// показаться хоть как-то, а не пустой строкой. Сторож на полноту —
/// `test/architecture/device_profile_labels_test.dart`.
library;

import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Название модели на языке интерфейса.
String deviceProfileTitle(DeviceProfile profile, AppLocalizations l10n) =>
    switch (profile.id) {
      'printer.escpos.80mm' => l10n.devProfilePrinterEscpos80mm,
      'printer.escpos.58mm-compact' => l10n.devProfilePrinterEscpos58mm,
      'printer.escpos.usb' => l10n.devProfilePrinterEscposUsb,
      'printer.escpos.bluetooth' => l10n.devProfilePrinterEscposBluetooth,
      'printer.escpos.serial' => l10n.devProfilePrinterEscposSerial,
      'printer.label.zpl.104mm' => l10n.devProfilePrinterLabelZpl104,
      'printer.label.epl.58mm' => l10n.devProfilePrinterLabelEpl58,
      'scanner.usb.hid' => l10n.devProfileScannerUsbHid,
      'scanner.bluetooth.hid' => l10n.devProfileScannerBluetoothHid,
      'scanner.camera' => l10n.devProfileScannerCamera,
      'scanner.serial' => l10n.devProfileScannerSerial,
      'scale.cas.pd2' => l10n.devProfileScaleCasPd2,
      'scale.cas.er-plus' => l10n.devProfileScaleCasErPlus,
      'drawer.rj11.via-printer' => l10n.devProfileDrawerViaPrinter,
      'drawer.rj11.standalone' => l10n.devProfileDrawerStandalone,
      'display.serial.vfd' => l10n.devProfileDisplayVfd,
      'display.serial.lcd-2x20' => l10n.devProfileDisplayLcd2x20,
      'display.serial.led8' => l10n.devProfileDisplayLed8,
      'payment.kaspi.pos' => l10n.devProfilePaymentKaspiPos,
      _ => profile.title,
    };

/// Подпись параметра подключения на языке интерфейса.
///
/// Ключ составной — профиль плюс параметр: `port` у сетевого принтера это
/// «по умолчанию 9100», а у терминала Kaspi «обычно 8888». Один ключ на имя
/// параметра подставил бы человеку неверное число.
String deviceParamDescription(
  DeviceProfile profile,
  DeviceConnectionParam param,
  AppLocalizations l10n,
) => switch ((profile.id, param.key)) {
  ('printer.escpos.80mm', 'ipAddress') ||
  ('printer.escpos.58mm-compact', 'ipAddress') => l10n.devParamPrinterIpAddress,
  ('printer.escpos.80mm', 'port') ||
  ('printer.escpos.58mm-compact', 'port') ||
  ('printer.label.zpl.104mm', 'port') ||
  ('printer.label.epl.58mm', 'port') => l10n.devParamTcpPort9100,
  ('printer.escpos.usb', 'devicePath') => l10n.devParamPrinterDevicePath,
  ('printer.escpos.bluetooth', 'macAddress') => l10n.devParamPrinterMac,
  ('printer.escpos.serial', 'comPort') => l10n.devParamPrinterComPort,
  ('printer.label.zpl.104mm', 'ipAddress') ||
  ('printer.label.epl.58mm', 'ipAddress') => l10n.devParamLabelPrinterIp,
  ('scanner.bluetooth.hid', 'macAddress') => l10n.devParamScannerMac,
  ('scanner.camera', 'cameraId') => l10n.devParamCameraId,
  ('scanner.serial', 'comPort') => l10n.devParamScannerComPort,
  ('scale.cas.pd2', 'comPort') ||
  ('scale.cas.er-plus', 'comPort') => l10n.devParamScaleComPort,
  ('drawer.rj11.standalone', 'comPort') => l10n.devParamDrawerComPort,
  ('display.serial.vfd', 'comPort') ||
  ('display.serial.lcd-2x20', 'comPort') ||
  ('display.serial.led8', 'comPort') => l10n.devParamDisplayComPort,
  ('payment.kaspi.pos', 'ipAddress') => l10n.devParamKaspiIp,
  ('payment.kaspi.pos', 'port') => l10n.devParamKaspiPort,
  _ => param.description,
};
