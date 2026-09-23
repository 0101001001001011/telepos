import 'package:decimal/decimal.dart';

class ShiftReceipt {
  ShiftReceipt({
    required this.shiftId,
    required this.shiftUserName,
    required this.shiftOpenTime,
    required this.shiftCloseTime,
    required this.saleAmount,
    required this.debtAmount,
    required this.cashInPos,
    required this.cashPaymentsSum,
    required this.paymentSums,
    this.openingCash,
    Decimal? certificatesIssued,
    Decimal? certificatesRedeemed,
    this.posName,
    this.companyName,
  }) : certificatesIssued = certificatesIssued ?? Decimal.zero,
       certificatesRedeemed = certificatesRedeemed ?? Decimal.zero;

  final int shiftId;

  final String shiftUserName;

  final int shiftOpenTime;

  final int shiftCloseTime;

  final Decimal saleAmount;

  final Decimal debtAmount;

  final Decimal cashInPos;

  /// Подъёмные смены; `null` — **не объявляли**, а не ноль.
  ///
  /// Разница не педантизм: ноль — законный результат объявления (ящик
  /// пуст), и подменять им «не знаем» значило бы разрешить запасному пути
  /// `ShiftNotifier._resolveOpeningCash` подставить в Z-отчёт остаток
  /// ПРОШЛОЙ смены там, где касса честно начала с пустого ящика. `null`
  /// приезжает только от смен, открытых до появления столбца
  /// `shifts.opening_cash`.
  final Decimal? openingCash;

  final Decimal cashPaymentsSum;

  final List<PaymentSumEntry> paymentSums;

  /// Сумма **номиналов** сертификатов, выпущенных за смену.
  ///
  /// # Зачем это отдельное число рядом с выручкой
  ///
  /// Деньги, полученные за проданный сертификат, — **не выручка**, а
  /// обязательство магазина (`AccountType.certificateLiability`). Они лежат
  /// в ящике, и кассир, сводящий кассу, обязан знать, что часть денег в
  /// ящике — чужие: товара на них ещё не отдано. Без этой строки X/Z-отчёт
  /// показывал их неотличимо от выручки, и владелец снимал их как прибыль.
  ///
  /// Источник и довод, почему именно он, — `CertificateDao
  /// .issuedNominalBetween`. Коротко: номинал бумажки, а не цена, за
  /// которую её продали, и не строки оплаты того чека.
  ///
  /// # Чего это число НЕ значит
  ///
  /// Не значит «столько наличных в ящике за сертификаты»: бумажку могли
  /// оплатить картой или завести переносом тиража вовсе без чека. И не
  /// значит «столько магазин должен на конец смены»: обязательство копится
  /// годами, а здесь движение одной смены.
  final Decimal certificatesIssued;

  /// Сумма строк оплаты **сертификатом** за смену.
  ///
  /// Зеркало [certificatesIssued] и ответ на другой вопрос: столько товара
  /// отдано **без живых денег**. Гашение — `FiscalTreatment.offsetNotFiscal`
  /// (решение заказчика 2026-09-14): не оплата ни для ОФД, ни для ящика, а
  /// закрытие ранее взятого обязательства товаром.
  ///
  /// Источник и довод — `PaymentDao.sumCertificateRedemptionsBetween`.
  ///
  /// # Чего это число НЕ значит
  ///
  /// Не уменьшает [saleAmount]: цена товара входит в выручку целиком, и
  /// вычитать одно из другого нельзя — чек мог быть доплачен наличными,
  /// которые в ящике есть.
  final Decimal certificatesRedeemed;

  final String? posName;

  final String? companyName;
}

class PaymentSumEntry {
  const PaymentSumEntry({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.amount,
    this.kindId,
    this.kindName,
  });

  final int accountId;

  final String accountName;

  final int accountType;

  final Decimal amount;

  /// Вид оплаты — **второе измерение отчёта**, заведённое задачей 14.
  ///
  /// До неё строка отчёта отвечала на вопрос «сколько пришло на этот
  /// счёт», и этого хватало ровно потому, что старый уникальный ключ
  /// `Payments` запрещал двум строкам одного чека лечь на один счёт.
  /// Ключ снят, запрет вместе с ним, и без этого поля отчёт слил бы
  /// наличные и карту, обе упавшие на счёт кассы, в одну строку.
  ///
  /// `null` — вид не записан (строки до v41) или счёт снесён. Такая
  /// строка приходит **отдельно**, а не подмешанной к наличным.
  final int? kindId;

  /// Имя вида **из справочника**, то есть настроенное оператором.
  final String? kindName;
}
