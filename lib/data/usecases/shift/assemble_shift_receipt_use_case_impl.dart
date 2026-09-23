import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/shift/shift_receipt.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/domain/usecases/shift/custom_bank_payments_sum_use_case.dart';

class AssembleShiftReceiptUseCaseImpl implements AssembleShiftReceiptUseCase {
  AssembleShiftReceiptUseCaseImpl({
    required AppDatabase db,
    required CustomBankPaymentsSumUseCase paymentsSumUseCase,
    required Talker logger,
  }) : _db = db,
       _paymentsSumUseCase = paymentsSumUseCase,
       _logger = logger;

  final AppDatabase _db;
  final CustomBankPaymentsSumUseCase _paymentsSumUseCase;
  final Talker _logger;

  @override
  Future<ShiftReceipt?> assemble(int shiftId, Decimal cashInPos) async {
    final shifts = await ((_db.select(
      _db.shifts,
    ))..where((sh) => sh.id.equals(shiftId))).get();

    if (shifts.isEmpty) {
      _logger.warning('AssembleShiftReceipt: shift $shiftId not found');
      return null;
    }

    final shift = shifts.first;
    final openTime = shift.openTime;
    final closeTime =
        shift.closeTime ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final userId = shift.userId;

    final user = await _db.userDao.findById(userId);
    final userName = user?.name ?? '';

    final thisPos = await _db.thisPosDao.get();

    var cashPaymentsSum = Decimal.zero;
    final posAccountId = thisPos?.accountId;
    if (posAccountId != null) {
      final sum = await _db.paymentDao.sumByUserAndPayeeAccountIdBetween(
        userId,
        posAccountId,
        openTime,
        closeTime,
      );
      if (sum != null) {
        cashPaymentsSum = Decimal.parse(sum.toStringAsFixed(3));
      }
    }

    final paymentSums = await _paymentsSumUseCase.getPaymentSums(
      userId: userId,
      openTime: openTime,
      closeTime: closeTime,
    );

    var saleAmount = Decimal.zero;
    final saleSum = await _db.saleDao.amountOfShift(
      userId,
      openTime,
      closeTime,
    );
    if (saleSum != null) {
      saleAmount = Decimal.parse(saleSum.toStringAsFixed(3));
    }

    // ── сертификаты: обязательство, а не выручка ──────────────────────
    //
    // Два числа, потому что вопроса два, и складывать их нельзя:
    // «на сколько выросло обязательство» и «сколько товара отдано без
    // живых денег». Разбор источников — в докстрингах
    // `CertificateDao.issuedNominalBetween` и
    // `PaymentDao.sumCertificateRedemptionsBetween`; оба числа сверены со
    // счётом обязательства пробой `certificate_shift_totals_test.dart`.
    //
    // Окно и кассир — **те же**, какими считаются продажи и оплаты выше.
    // Взять другое окно значило бы напечатать на одном листе числа за
    // разные промежутки, и расхождение никто бы не заметил.
    final certificatesIssued = await _db.certificateDao.issuedNominalBetween(
      from: openTime,
      to: closeTime,
      userId: userId,
    );
    final certificatesRedeemed = await _db.paymentDao
        .sumCertificateRedemptionsBetween(
          userId: userId,
          startDate: openTime,
          endDate: closeTime,
        );

    var totalPayments = Decimal.zero;
    for (final entry in paymentSums) {
      totalPayments += entry.amount;
    }
    final debtAmount = saleAmount - totalPayments;

    return ShiftReceipt(
      shiftId: shiftId,
      shiftUserName: userName,
      shiftOpenTime: openTime,
      shiftCloseTime: closeTime,
      saleAmount: saleAmount,
      debtAmount: debtAmount,
      cashInPos: cashInPos,
      // Подъёмные смены. Их здесь НЕ БЫЛО вовсе до 2026-09-22: поле
      // конструктора существовало, звавший его не заполнял, и
      // `ShiftReceipt.openingCash` всегда приезжал нулём. Экран смены
      // прикрывал дыру `_resolveOpeningCash` — подставлял остаток ПРОШЛОЙ
      // смены, — и в строке «На начало» Z-отчёта печаталось чужое число.
      openingCash: shift.openingCash,
      cashPaymentsSum: cashPaymentsSum,
      paymentSums: paymentSums,
      certificatesIssued: certificatesIssued,
      certificatesRedeemed: certificatesRedeemed,
      posName: thisPos?.cashBoxName,
      companyName: thisPos?.companyName,
    );
  }
}
