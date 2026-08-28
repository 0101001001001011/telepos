import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/refund_validation_service.dart';

class RefundValidationServiceImpl implements RefundValidationService {
  RefundValidationServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _accountTypeBank = 1;

  @override
  QuantityValidation validateQuantity({
    required Decimal refundQuantity,
    required Decimal saleQuantity,
    Decimal? alreadyRefundedQuantity,
  }) {
    final refundedQty = alreadyRefundedQuantity ?? Decimal.zero;
    if (refundQuantity <= Decimal.zero) {
      _logger.warning('RefundValidation: quantity not positive');
      return const QuantityValidation(
        isValid: false,
        error: QuantityError.notPositive,
      );
    }

    final maxAllowed = saleQuantity - refundedQty;
    if (refundQuantity > maxAllowed) {
      _logger.warning(
        'RefundValidation: quantity $refundQuantity > max allowed $maxAllowed',
      );
      return QuantityValidation(
        isValid: false,
        error: QuantityError.exceedsOriginal,
        maxAllowedQuantity: maxAllowed,
      );
    }

    return const QuantityValidation(isValid: true);
  }

  @override
  Future<bool> hasExistingRefund({
    required int saleReceiptNo,
    required int salePosId,
  }) async {
    final existingRefund = await _db.refundDao.findBySale(
      saleReceiptNo,
      salePosId,
    );

    if (existingRefund != null) {
      _logger.warning(
        'RefundValidation: existing refund found for sale '
        'receiptNo=$saleReceiptNo, posId=$salePosId',
      );
      return true;
    }

    return false;
  }

  @override
  Future<AcquiringValidation> validateAcquiring({
    required int saleReceiptNo,
    required int salePosId,
  }) async {
    final salePayments = await _db.paymentDao.findBySale(
      saleReceiptNo,
      salePosId,
    );

    final thisPos = await _db.thisPosDao.get();
    final currentPosId = thisPos?.id;

    for (final payment in salePayments) {
      final account = await _db.accountDao.findById(payment.payeeAccountId);
      if (account != null && account.type == _accountTypeBank) {
        if (salePosId != currentPosId) {
          _logger.warning(
            'RefundValidation: acquiring from different POS '
            'salePosId=$salePosId, currentPosId=$currentPosId',
          );
          return AcquiringValidation(
            isValid: false,
            error: AcquiringError.differentPos,
            acquiringPosId: salePosId,
          );
        }
      }
    }

    return const AcquiringValidation(isValid: true);
  }

  @override
  Future<bool> isProductInSale({
    required int ucode,
    required int saleReceiptNo,
    required int salePosId,
  }) async {
    final saleProducts = await _db.saleProductDao.findBySale(
      saleReceiptNo,
      salePosId,
    );

    for (final sp in saleProducts) {
      if (sp.ucode == ucode) {
        return true;
      }
    }

    _logger.warning(
      'RefundValidation: product ucode=$ucode not found in sale '
      'receiptNo=$saleReceiptNo, posId=$salePosId',
    );
    return false;
  }

  @override
  Future<bool> agentExists({required int agentLocalId}) async {
    final agents = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).get();

    if (agents.isEmpty) {
      _logger.warning(
        'RefundValidation: agent not found localId=$agentLocalId',
      );
      return false;
    }

    return true;
  }

  @override
  AmountValidation validateAmount(Decimal amount) {
    if (amount >= AmountValidation.warningThreshold) {
      _logger.info(
        'RefundValidation: large amount $amount >= ${AmountValidation.warningThreshold}',
      );
      return const AmountValidation(isValid: true, needsConfirmation: true);
    }

    return const AmountValidation(isValid: true);
  }

  @override
  RefundValidation validateRefund({
    required int productCount,
    required bool hasZeroPriceProduct,
    required Decimal refundAmount,
    required bool hasFullDiscount,
  }) {
    if (productCount == 0) {
      _logger.warning('RefundValidation: empty cart');
      return const RefundValidation(
        isValid: false,
        error: RefundError.emptyCart,
      );
    }

    if (hasZeroPriceProduct && !hasFullDiscount) {
      _logger.warning('RefundValidation: has zero price product');
      return const RefundValidation(
        isValid: false,
        error: RefundError.hasZeroPrice,
      );
    }

    if (refundAmount <= Decimal.zero && !hasFullDiscount) {
      _logger.warning('RefundValidation: zero amount');
      return const RefundValidation(
        isValid: false,
        error: RefundError.zeroAmount,
      );
    }

    if (refundAmount >= AmountValidation.warningThreshold) {
      _logger.info(
        'RefundValidation: large amount $refundAmount needs confirmation',
      );
      return const RefundValidation(isValid: true, needsConfirmation: true);
    }

    return const RefundValidation(isValid: true);
  }
}
