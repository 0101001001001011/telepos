import 'package:decimal/decimal.dart';

class ShiftEntity {
  const ShiftEntity({
    this.id,
    required this.userId,
    required this.openTime,
    required this.isOpened,
    this.closeTime,
    this.cashInPosOnShiftClose,
    this.isSynced = false,
  });

  final int? id;

  final int userId;

  final int openTime;

  final bool isOpened;

  final int? closeTime;

  final Decimal? cashInPosOnShiftClose;

  final bool isSynced;

  bool get isClosed => !isOpened;

  int? get durationSeconds => closeTime != null ? closeTime! - openTime : null;

  ShiftEntity copyWith({
    int? id,
    int? userId,
    int? openTime,
    bool? isOpened,
    int? closeTime,
    bool clearCloseTime = false,
    Decimal? cashInPosOnShiftClose,
    bool clearCashInPos = false,
    bool? isSynced,
  }) {
    return ShiftEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      openTime: openTime ?? this.openTime,
      isOpened: isOpened ?? this.isOpened,
      closeTime: clearCloseTime ? null : (closeTime ?? this.closeTime),
      cashInPosOnShiftClose: clearCashInPos
          ? null
          : (cashInPosOnShiftClose ?? this.cashInPosOnShiftClose),
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
