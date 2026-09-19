/// Сертификат и аванс в фискальном документе — **три решения оператора**.
///
/// Решения заказчика 2026-09-14 (план
/// `docs/internal/superpowers/plans/2026-09-14-sale-remaining.md`, группа A;
/// разбор `docs/internal/research/2026-09-14-certificate-prepayment-
/// fiscal-kz.md`). Хранятся строкой `ThisPos` (миграция v47).
library;

import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

/// Как чек закрывает разницу между позициями и живыми деньгами, когда часть
/// чека оплачена зачётом ([FiscalTreatment.offsetNotFiscal]).
///
/// Индекс члена лежит на диске (`this_pos_entries.offset_fiscal_layout`):
/// новые члены — только в конец.
enum OffsetFiscalLayout {
  /// Сумма зачёта — **скидкой позиций**, цена позиции полная. Практика
  /// 1С:Розница КЗ. У скидки в ОФД нет признака сертификата — у оператора
  /// она неотличима от обычной скидки (заказчику известно).
  discount,

  /// Фискальный чек **только на доплату**: сумма зачёта уменьшает цену
  /// позиций, поля скидки на ней нет. Чек без живых денег документа не
  /// даёт вовсе.
  surchargeOnly;

  /// Незнакомое число — умолчание, а не бросок: строка приехала от кассы
  /// более новой сборки, и чек продать всё равно надо.
  static OffsetFiscalLayout byIndex(int? value) =>
      value != null && value >= 0 && value < values.length
      ? values[value]
      : OffsetFiscalLayout.discount;
}

/// Три настройки кассы о сертификате и авансе.
class FiscalOffsetSettings {
  const FiscalOffsetSettings({
    this.fiscalizeCertificateSale = false,
    this.offsetLayout = OffsetFiscalLayout.discount,
    this.fiscalizePrepaymentReceipt = true,
  });

  /// Умолчания поставки — решение заказчика 2026-09-14.
  static const FiscalOffsetSettings defaults = FiscalOffsetSettings();

  /// Фискальный чек **продажи** сертификата. По умолчанию выкл; КГД
  /// 09.09.2020 и 24.11.2021 требуют чек — оператор включает сам.
  final bool fiscalizeCertificateSale;

  /// Раскладка гашения/зачёта. По умолчанию — скидкой.
  final OffsetFiscalLayout offsetLayout;

  /// Фискальный чек **приёма** аванса. По умолчанию вкл (КГД 11.06.2019,
  /// 18.06.2019, 15.10.2021: чек при получении денег).
  final bool fiscalizePrepaymentReceipt;

  FiscalOffsetSettings copyWith({
    bool? fiscalizeCertificateSale,
    OffsetFiscalLayout? offsetLayout,
    bool? fiscalizePrepaymentReceipt,
  }) => FiscalOffsetSettings(
    fiscalizeCertificateSale:
        fiscalizeCertificateSale ?? this.fiscalizeCertificateSale,
    offsetLayout: offsetLayout ?? this.offsetLayout,
    fiscalizePrepaymentReceipt:
        fiscalizePrepaymentReceipt ?? this.fiscalizePrepaymentReceipt,
  );

  /// Чем строка этого вида **действительно** уйдёт оператору.
  ///
  /// # Сторож, а не пожелание (решения 1 и 5)
  ///
  /// Трактовка вида — настройка справочника, и оператор (или база,
  /// прошедшая v41 до этой сборки) вправе назвать зачёт наличными. Но два
  /// сочетания — **двойная выручка по ККМ**, и они запрещены построением:
  ///
  /// * **Гашение сертификата** (зачёт на счёт обязательства) — никогда не
  ///   фискальная оплата. Деньги прошли при продаже бумажки; при гашении
  ///   денежного расчёта нет (КГД 2020, 2021).
  /// * **Зачёт аванса** (зачёт на расчётный счёт покупателя) при
  ///   фискализованном приёме: те же деньги уже прошли чеком приёма.
  ///
  /// В обоих случаях трактовка-платёж (`cash`/`card`/`mobile`/`credit`/
  /// `tare`) становится [FiscalTreatment.offsetNotFiscal]. `notAPayment`
  /// остаётся собой: скидка двойной выручки не даёт.
  ///
  /// Признак — **род расчёта и род счёта-получателя вида**, а не его ид:
  /// пользовательский вид сертификата гасится тем же правилом.
  FiscalTreatment effectiveTreatment(PaymentKind kind) {
    final declared = kind.fiscalTreatment;
    if (kind.settlement != PaymentSettlement.offset) return declared;

    final forbidPayment = switch (kind.payeeAccountType) {
      AccountType.certificateLiability => true,
      AccountType.agentMain => fiscalizePrepaymentReceipt,
      _ => false,
    };
    if (!forbidPayment) return declared;

    return switch (declared) {
      FiscalTreatment.cash => FiscalTreatment.offsetNotFiscal,
      FiscalTreatment.card => FiscalTreatment.offsetNotFiscal,
      FiscalTreatment.credit => FiscalTreatment.offsetNotFiscal,
      FiscalTreatment.mobile => FiscalTreatment.offsetNotFiscal,
      FiscalTreatment.tare => FiscalTreatment.offsetNotFiscal,
      FiscalTreatment.notAPayment => FiscalTreatment.notAPayment,
      FiscalTreatment.offsetNotFiscal => FiscalTreatment.offsetNotFiscal,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FiscalOffsetSettings &&
      other.fiscalizeCertificateSale == fiscalizeCertificateSale &&
      other.offsetLayout == offsetLayout &&
      other.fiscalizePrepaymentReceipt == fiscalizePrepaymentReceipt;

  @override
  int get hashCode => Object.hash(
    fiscalizeCertificateSale,
    offsetLayout,
    fiscalizePrepaymentReceipt,
  );

  @override
  String toString() =>
      'FiscalOffsetSettings(certificateSale: $fiscalizeCertificateSale, '
      'layout: ${offsetLayout.name}, prepaymentReceipt: '
      '$fiscalizePrepaymentReceipt)';
}

/// Где лежат [FiscalOffsetSettings]. Экран настроек пишет, касса читает.
abstract interface class FiscalOffsetSettingsStore {
  Future<FiscalOffsetSettings> load();

  Future<void> save(FiscalOffsetSettings settings);
}
