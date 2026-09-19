import 'dart:math' as math;

import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/terminal/device_binding.dart';

/// Ширина ленты того чекового принтера, на который уйдут байты документа.
///
/// ## Один источник правды — и почему именно этот
///
/// Жалоба заказчика с XPrinter: «постоянно печатался узкий чек, даже если
/// выбирали широкий». Измерено (`receipt_paper_width_wire_test.dart`, девять
/// путей печати из девяти): ширину помнили **четыре** места, и ни одно не
/// слушало другое —
///
/// * опция `paperWidthMm` привязки чекового принтера — её сохраняет экран
///   «Настройки принтера» и мастер; **её не читал ни один построитель чека**;
/// * `ReceiptOptions.paperWidth` шаблона чека — засевался мастером один раз и
///   больше не менялся, умолчание 58 мм;
/// * `ThisPosEntries.paperWidth` — квитанция кассовой операции;
/// * литерал `32` в `ReceiptPrintServiceImpl` — X/Z-отчёты, пречек, квитанции
///   сервиса.
///
/// Ширина ленты — свойство **прибора** (какой рулон стоит в этом принтере), а
/// не оформления чека и не установки. Поэтому источник — привязка принтера:
/// та самая, по которой очередь находит, куда слать байты. Шаблон, установка и
/// литералы ширину больше не несут вовсе — второе место, помнящее ширину, и
/// было дефектом.
///
/// Читается **при каждой печати**, а не при старте: ширина, сменённая на
/// экране принтера, действует со следующего чека.
abstract interface class ReceiptPaperWidthSource {
  Future<ReceiptPaperWidth> current();
}

/// Ширина, известная заранее, — для предпросмотра с явно выбранной шириной и
/// для проб, которым привязка не нужна.
class FixedReceiptPaperWidth implements ReceiptPaperWidthSource {
  const FixedReceiptPaperWidth(this.width);

  final ReceiptPaperWidth width;

  @override
  Future<ReceiptPaperWidth> current() async => width;
}

/// Ширина ленты по привязкам **этого** терминала.
///
/// * Чековый принтер — ровно один включённый и прошедший проверку профиля.
///   Ноль или больше одного — принтера у кассы нет (`hardware_module.dart`
///   `_resolveSingleBinding` в этом случае драйвер не регистрирует), печатать
///   некуда, и возвращается узкая лента: узкий чек читается на любой ленте, а
///   широкий на узкой ломается переносами принтера.
/// * Выбранная опция `paperWidthMm` — ответ.
/// * Опция не выбрана — самая узкая из ширин, которые допускает профиль, по
///   тому же доводу.
ReceiptPaperWidth receiptPaperWidthOf(
  List<DeviceBinding> bindings,
  DeviceProfileCatalog catalog,
) {
  final printers = <DeviceBinding>[];
  for (final binding in bindings) {
    if (binding.deviceClass != DeviceClass.receiptPrinter) continue;
    if (!binding.enabled) continue;
    try {
      binding.validateAgainst(catalog);
    } on ArgumentError {
      continue;
    }
    printers.add(binding);
  }
  if (printers.length != 1) return ReceiptPaperWidth.mm58;

  final binding = printers.single;
  final chosen = int.tryParse(binding.options[paperWidthOptionKey] ?? '');
  if (chosen != null) return ReceiptPaperWidth.fromMm(chosen);

  final allowed =
      catalog.byId(binding.profileId)?.capabilities.paperWidthsMm ?? const [];
  if (allowed.isEmpty) return ReceiptPaperWidth.mm58;
  return ReceiptPaperWidth.fromMm(allowed.reduce(math.min));
}

/// Ключ опции ширины ленты — `DeviceProfile.options`.
const String paperWidthOptionKey = 'paperWidthMm';
