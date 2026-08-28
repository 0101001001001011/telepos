import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/restaurant/selected_modifier.dart';

abstract class AddItemsToOrderUseCase {
  Future<int> addItem({
    required int orderId,
    required int productUcode,
    required Decimal quantity,
    required Decimal price,
    int guestNumber = 0,
    List<SelectedModifier> modifiers = const [],
  });

  Future<void> removeItem(int orderId, int saleProductId);

  Future<void> updateItemQuantity(int saleProductId, Decimal quantity);
}
