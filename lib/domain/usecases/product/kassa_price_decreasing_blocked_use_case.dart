import 'package:decimal/decimal.dart';

abstract class KassaPriceDecreasingBlockedUseCase {
  Future<bool> isBlocked();

  Future<PriceChangeValidation> validatePriceChange({
    required int ucode,
    required Decimal newPrice,
  });
}

class PriceChangeValidation {
  const PriceChangeValidation({
    required this.isAllowed,
    this.currentPrice,
    this.reason,
  });

  final bool isAllowed;

  final Decimal? currentPrice;

  final String? reason;

  factory PriceChangeValidation.allowed() =>
      const PriceChangeValidation(isAllowed: true);

  factory PriceChangeValidation.blocked({
    required Decimal currentPrice,
    required Decimal newPrice,
  }) => PriceChangeValidation(
    isAllowed: false,
    currentPrice: currentPrice,
    reason:
        'Снижение цены запрещено. '
        'Текущая: $currentPrice, новая: $newPrice',
  );

  factory PriceChangeValidation.productNotFound(int ucode) =>
      PriceChangeValidation(
        isAllowed: false,
        reason: 'Товар ucode=$ucode не найден',
      );
}
