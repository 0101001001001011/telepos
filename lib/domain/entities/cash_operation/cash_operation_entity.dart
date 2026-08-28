import 'package:decimal/decimal.dart';

class CashOperationEntity {
  const CashOperationEntity({
    this.id,
    this.storeId,
    required this.amount,
    this.accountId,
    required this.type,
    this.userId,
    this.note,
    this.docTime,
    this.state,
  });

  final int? id;

  final int? storeId;

  final Decimal amount;

  final int? accountId;

  final int type;

  final int? userId;

  final String? note;

  final int? docTime;

  final int? state;

  bool get isInvestment => type == 0;

  bool get isExpense => type == 1;

  bool get isDividend => type == 2;

  CashOperationEntity copyWith({
    int? id,
    int? storeId,
    Decimal? amount,
    int? accountId,
    int? type,
    int? userId,
    String? note,
    int? docTime,
    int? state,
  }) {
    return CashOperationEntity(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      note: note ?? this.note,
      docTime: docTime ?? this.docTime,
      state: state ?? this.state,
    );
  }
}
