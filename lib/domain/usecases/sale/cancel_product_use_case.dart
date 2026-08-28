import 'package:decimal/decimal.dart';

abstract class CancelProductUseCase {
  Future<void> onCancel({
    required int ucode,
    required Decimal expectedQuantity,
    required Decimal cancelledQuantity,
  });
}
