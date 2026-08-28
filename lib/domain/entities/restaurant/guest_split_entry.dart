import 'package:decimal/decimal.dart';

class GuestSplitEntry {
  const GuestSplitEntry({
    this.id,
    required this.orderId,
    required this.guestNumber,
    required this.saleProductId,
    required this.shareQuantity,
  });

  final int? id;
  final int orderId;
  final int guestNumber;
  final int saleProductId;
  final Decimal shareQuantity;

  GuestSplitEntry copyWith({
    int? id,
    int? orderId,
    int? guestNumber,
    int? saleProductId,
    Decimal? shareQuantity,
  }) {
    return GuestSplitEntry(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      guestNumber: guestNumber ?? this.guestNumber,
      saleProductId: saleProductId ?? this.saleProductId,
      shareQuantity: shareQuantity ?? this.shareQuantity,
    );
  }
}
