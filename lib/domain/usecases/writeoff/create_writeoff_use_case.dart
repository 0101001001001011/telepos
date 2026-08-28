import 'package:decimal/decimal.dart';

enum WriteoffReason {
  breakage(0),

  expired(1),

  spoilage(2),

  loss(3),

  other(4);

  const WriteoffReason(this.value);
  final int value;

  static WriteoffReason fromValue(int value) => switch (value) {
    0 => breakage,
    1 => expired,
    2 => spoilage,
    3 => loss,
    _ => other,
  };
}

class WriteoffProductEntry {
  const WriteoffProductEntry({
    required this.ucode,
    required this.quantity,
    required this.price,
    this.productName,
  });

  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final String? productName;

  Decimal get amount => quantity * price;
}

class CreateWriteoffResult {
  const CreateWriteoffResult._({
    this.writeoffId,
    this.totalAmount,
    this.productCount = 0,
    this.success = false,
    this.errorMessage,
  });

  factory CreateWriteoffResult.saved({
    required int writeoffId,
    required Decimal totalAmount,
    required int productCount,
  }) => CreateWriteoffResult._(
    writeoffId: writeoffId,
    totalAmount: totalAmount,
    productCount: productCount,
    success: true,
  );

  factory CreateWriteoffResult.failed(String message) =>
      CreateWriteoffResult._(errorMessage: message);

  final int? writeoffId;
  final Decimal? totalAmount;
  final int productCount;
  final bool success;
  final String? errorMessage;
}

abstract class CreateWriteoffUseCase {
  Future<CreateWriteoffResult> create({
    required WriteoffReason reason,
    required List<WriteoffProductEntry> products,
    String? comment,
    int? userId,
  });
}
