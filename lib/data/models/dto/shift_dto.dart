library;

class ShiftDto {
  const ShiftDto({
    required this.id,
    required this.posId,
    required this.userId,
    required this.status,
    this.openedAt,
    this.closedAt,
    this.openingCash,
    this.closingCash,
    this.salesCount,
    this.salesAmount,
    this.refundsCount,
    this.refundsAmount,
    this.syncState,
  });

  final int id;
  final int posId;
  final int userId;
  final String status;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? openingCash;
  final String? closingCash;
  final int? salesCount;
  final String? salesAmount;
  final int? refundsCount;
  final String? refundsAmount;
  final String? syncState;

  factory ShiftDto.fromJson(Map<String, dynamic> json) {
    return ShiftDto(
      id: json['id'] as int,
      posId: json['posId'] as int,
      userId: json['userId'] as int,
      status: json['status'] as String,
      openedAt: json['openedAt'] != null
          ? DateTime.parse(json['openedAt'] as String)
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
      openingCash: json['openingCash'] as String?,
      closingCash: json['closingCash'] as String?,
      salesCount: json['salesCount'] as int?,
      salesAmount: json['salesAmount'] as String?,
      refundsCount: json['refundsCount'] as int?,
      refundsAmount: json['refundsAmount'] as String?,
      syncState: json['syncState'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'posId': posId,
      'userId': userId,
      'status': status,
      if (openedAt != null) 'openedAt': openedAt!.toIso8601String(),
      if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
      if (openingCash != null) 'openingCash': openingCash,
      if (closingCash != null) 'closingCash': closingCash,
      if (salesCount != null) 'salesCount': salesCount,
      if (salesAmount != null) 'salesAmount': salesAmount,
      if (refundsCount != null) 'refundsCount': refundsCount,
      if (refundsAmount != null) 'refundsAmount': refundsAmount,
      if (syncState != null) 'syncState': syncState,
    };
  }
}

class ShiftReportDto {
  const ShiftReportDto({
    required this.shiftId,
    required this.posId,
    required this.userId,
    required this.openedAt,
    this.closedAt,
    this.openingCash,
    this.closingCash,
    this.salesCount,
    this.salesAmount,
    this.cashSalesAmount,
    this.cardSalesAmount,
    this.refundsCount,
    this.refundsAmount,
    this.cashRefundsAmount,
    this.cardRefundsAmount,
    this.investmentAmount,
    this.expenseAmount,
    this.expectedCash,
    this.actualCash,
    this.difference,
  });

  final int shiftId;
  final int posId;
  final int userId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? openingCash;
  final String? closingCash;
  final int? salesCount;
  final String? salesAmount;
  final String? cashSalesAmount;
  final String? cardSalesAmount;
  final int? refundsCount;
  final String? refundsAmount;
  final String? cashRefundsAmount;
  final String? cardRefundsAmount;
  final String? investmentAmount;
  final String? expenseAmount;
  final String? expectedCash;
  final String? actualCash;
  final String? difference;

  factory ShiftReportDto.fromJson(Map<String, dynamic> json) {
    return ShiftReportDto(
      shiftId: json['shiftId'] as int,
      posId: json['posId'] as int,
      userId: json['userId'] as int,
      openedAt: DateTime.parse(json['openedAt'] as String),
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
      openingCash: json['openingCash'] as String?,
      closingCash: json['closingCash'] as String?,
      salesCount: json['salesCount'] as int?,
      salesAmount: json['salesAmount'] as String?,
      cashSalesAmount: json['cashSalesAmount'] as String?,
      cardSalesAmount: json['cardSalesAmount'] as String?,
      refundsCount: json['refundsCount'] as int?,
      refundsAmount: json['refundsAmount'] as String?,
      cashRefundsAmount: json['cashRefundsAmount'] as String?,
      cardRefundsAmount: json['cardRefundsAmount'] as String?,
      investmentAmount: json['investmentAmount'] as String?,
      expenseAmount: json['expenseAmount'] as String?,
      expectedCash: json['expectedCash'] as String?,
      actualCash: json['actualCash'] as String?,
      difference: json['difference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftId': shiftId,
      'posId': posId,
      'userId': userId,
      'openedAt': openedAt.toIso8601String(),
      if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
      if (openingCash != null) 'openingCash': openingCash,
      if (closingCash != null) 'closingCash': closingCash,
      if (salesCount != null) 'salesCount': salesCount,
      if (salesAmount != null) 'salesAmount': salesAmount,
      if (cashSalesAmount != null) 'cashSalesAmount': cashSalesAmount,
      if (cardSalesAmount != null) 'cardSalesAmount': cardSalesAmount,
      if (refundsCount != null) 'refundsCount': refundsCount,
      if (refundsAmount != null) 'refundsAmount': refundsAmount,
      if (cashRefundsAmount != null) 'cashRefundsAmount': cashRefundsAmount,
      if (cardRefundsAmount != null) 'cardRefundsAmount': cardRefundsAmount,
      if (investmentAmount != null) 'investmentAmount': investmentAmount,
      if (expenseAmount != null) 'expenseAmount': expenseAmount,
      if (expectedCash != null) 'expectedCash': expectedCash,
      if (actualCash != null) 'actualCash': actualCash,
      if (difference != null) 'difference': difference,
    };
  }
}
