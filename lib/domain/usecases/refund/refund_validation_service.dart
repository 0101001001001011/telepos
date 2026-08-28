import 'package:decimal/decimal.dart';

abstract class RefundValidationService {
  QuantityValidation validateQuantity({
    required Decimal refundQuantity,
    required Decimal saleQuantity,
    Decimal? alreadyRefundedQuantity,
  });

  Future<bool> hasExistingRefund({
    required int saleReceiptNo,
    required int salePosId,
  });

  Future<AcquiringValidation> validateAcquiring({
    required int saleReceiptNo,
    required int salePosId,
  });

  Future<bool> isProductInSale({
    required int ucode,
    required int saleReceiptNo,
    required int salePosId,
  });

  Future<bool> agentExists({required int agentLocalId});

  AmountValidation validateAmount(Decimal amount);

  RefundValidation validateRefund({
    required int productCount,
    required bool hasZeroPriceProduct,
    required Decimal refundAmount,
    required bool hasFullDiscount,
  });
}

class QuantityValidation {
  const QuantityValidation({
    required this.isValid,
    this.error,
    this.maxAllowedQuantity,
  });

  final bool isValid;
  final QuantityError? error;
  final Decimal? maxAllowedQuantity;
}

enum QuantityError { exceedsOriginal, notPositive }

class AcquiringValidation {
  const AcquiringValidation({
    required this.isValid,
    this.error,
    this.acquiringPosId,
  });

  final bool isValid;
  final AcquiringError? error;

  final int? acquiringPosId;
}

enum AcquiringError { differentPos }

class AmountValidation {
  const AmountValidation({
    required this.isValid,
    this.needsConfirmation = false,
  });

  final bool isValid;

  final bool needsConfirmation;

  static final Decimal warningThreshold = Decimal.fromInt(1000000);
}

class RefundValidation {
  const RefundValidation({
    required this.isValid,
    this.error,
    this.needsConfirmation = false,
  });

  final bool isValid;
  final RefundError? error;

  final bool needsConfirmation;
}

enum RefundError { emptyCart, hasZeroPrice, zeroAmount, amountTooLarge }
