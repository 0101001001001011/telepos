import 'package:decimal/decimal.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

abstract interface class FiscalService {
  Future<FiscalSettings> currentSettings();

  Future<bool> isEnabled();

  /// Фискальный документ продажи.
  ///
  /// [bonusAmount] — сколько чека покрыл **списанный бонус покупателя**.
  ///
  /// Довод **обязательный намеренно**. Бонус уходит с бонусного счёта, в
  /// [cashAmount]/[cardAmount] не попадает и попасть не может (раскладка
  /// смотрит на тип счёта получателя), а позиции строятся на полную
  /// сумму. Забыть его значит отправить оператору «позиций на 300, оплат
  /// на 200» и получить отказ кодом 9 — «деньги взяты, документа нет» на
  /// **каждой** продаже с бонусом. Ровно так это и было до задачи 7,
  /// когда довода не существовало. Необязательный довод с нулём по
  /// умолчанию вернул бы ту же дорогу молчанием; здесь её нет —
  /// пропустить бонус можно только написав `Decimal.zero` своей рукой.
  ///
  /// Фискально бонус — **скидка, а не платёж**: он входит слагаемым в
  /// поле `Discount` позиций (`FiscalPositionBuilder.distributeBonus` +
  /// `lineDiscount`). Разбор, почему не платёж, — в докстринге
  /// `FiscalPositionBuilder`.
  ///
  /// # Четыре ведра живых денег и зачёт — решения заказчика 2026-09-14
  ///
  /// [mobileAmount] — оплата телефоном (QR/СБП), `PaymentType 4`. До него у
  /// конверта было два денежных ведра, и QR ехал оператору картой.
  ///
  /// [offsetAmount] — **зачёт денег, прошедших через кассу раньше**:
  /// гашение сертификата, зачёт аванса при фискализованном приёме
  /// (`FiscalTreatment.offsetNotFiscal`). В `Payments` не попадает никогда.
  /// Разницу позиций и оплат закрывает [offsetLayout]: скидкой позиций или
  /// ценой позиций (чек только на доплату).
  ///
  /// [excludeCertificatePositions] — строки товара рода
  /// `ProductType.giftCertificate` в документ не идут (продажа сертификата
  /// без чека, настройка по умолчанию). Живые деньги за них вызывающий
  /// **уже вычел** из вёдер: сторож сводит конверт перед отправкой.
  ///
  /// Все доводы обязательны тем же доводом, что и [bonusAmount].
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  });

  /// Фискальный документ возврата.
  ///
  /// Вёдра — **то, что вернулось живыми деньгами**, по виду строки продажи
  /// (карта — картой, телефон — телефоном). [offsetAmount] — то, что
  /// вернулось на сертификат или в аванс: фискальным возвратом денег оно не
  /// является и раскладывается по позициям так же, как при продаже.
  ///
  /// Задача 26: [bonusAmount] — сколько вернулось на бонусный счёт; в
  /// документе это **скидка позиций**, как у продажи, а не деньги.
  /// [creditAmount] — сколько погасило долг; в документе это **не оплата**
  /// (`PaymentType 2` исключён протоколом ОФД 2.0.2), а раскладка позиций тем
  /// же [offsetLayout], что у зачёта. [excludeCertificatePositions] — строки
  /// проданных сертификатов в документ не идут (зеркало продажи, A1).
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  });

  /// Фискальный чек **приёма аванса** — решение заказчика 2026-09-14, п.4.
  ///
  /// Чек продажи в момент получения денег: одна позиция [positionName]
  /// («Аванс (предоплата) …») на [amount], тип оплаты — **фактический**
  /// ([paymentKind]: наличные, карта, мобильный). КГД 11.06.2019,
  /// 18.06.2019, 15.10.2021.
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  });

  /// Фискальный **возврат** аванса деньгами — дыра, найденная ревизией
  /// 2026-09-19.
  ///
  /// # Почему он обязан быть здесь, а не изъятием из ящика
  ///
  /// Приём аванса даёт чек ([fiscalizePrepayment]); выдача не давала
  /// никакого документа, потому что пути выдачи в кассе не было вовсе.
  /// Единственное, чем деньги могли выйти, — «Расход»
  /// (`CashInOutController.createExpense` → [moneyOut]), а это **служебное
  /// изъятие**: у оператора оно не уменьшает выручку смены и не является
  /// возвратом расчёта, и счёт покупателя от него не двигается. По смене
  /// деньги ушли, документа нет — ровно то, что назвал заказчик.
  ///
  /// Документ — возврат продажи ([FiscalOperationKind.saleReturn]) с одной
  /// позицией [positionName] на [amount] и **фактическим** [paymentKind]:
  /// зеркало приёма во всём, включая ноль НДС.
  ///
  /// [operationId] — номер проводки `cash_operations`, которой деньги
  /// вышли; он же ключ идемпотентности (того же вида, что у приёма).
  /// [intakeOperationId] — проводка **приёма**, если вызывающий её знает:
  /// её чек становится основанием возврата. `null` значит «не назван», а
  /// не «не было» — разбор в `FiscalServiceImpl._prepaymentRefundBasis`.
  ///
  /// # Настройка одна на приём и на выдачу
  ///
  /// Слушаться `FiscalOffsetSettings.fiscalizePrepaymentReceipt` обязан
  /// **вызывающий**, и той же настройкой, что приём: касса, где приём не
  /// фискальный, а выдача фискальная, показала бы оператору возврат денег,
  /// которые к нему никогда не приходили.
  Future<FiscalResult> fiscalizePrepaymentRefund({
    required int operationId,
    required int? intakeOperationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  });

  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req);

  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req);

  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  });

  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  });

  Future<FiscalResult> openShift();

  Future<FiscalReportResult> closeShift();

  Future<FiscalReportResult> xReport();

  Future<FiscalResult> correction(FiscalCorrectionRequest req);

  Future<FiscalStatus> status();
}

abstract interface class FiscalSettingsSource {
  Future<FiscalSettings> load();
}
