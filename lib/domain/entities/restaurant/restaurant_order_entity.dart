import 'package:decimal/decimal.dart';
import 'package:telepos/core/constants/enums/order_type.dart';

class RestaurantOrderEntity {
  const RestaurantOrderEntity({
    required this.id,
    this.tableId,
    this.receiptNo,
    this.posId,
    this.partySize = 1,
    this.orderType = OrderType.dineIn,
    required this.openTime,
    this.closeTime,
    this.waiterId,
    this.tips,
    this.deliveryAddress,
    this.deliveryPhone,
    this.note,
  });

  final int id;
  final int? tableId;
  final int? receiptNo;
  final int? posId;
  final int partySize;
  final OrderType orderType;
  final int openTime;
  final int? closeTime;
  final int? waiterId;
  final Decimal? tips;
  final String? deliveryAddress;
  final String? deliveryPhone;
  final String? note;

  bool get isOpen => closeTime == null;
  bool get isClosed => closeTime != null;
  bool get isDineIn => orderType == OrderType.dineIn;
  bool get isTakeout => orderType == OrderType.takeout;
  bool get isDelivery => orderType == OrderType.delivery;
  bool get isLinkedToSale => receiptNo != null && posId != null;

  RestaurantOrderEntity copyWith({
    int? id,
    int? tableId,
    int? receiptNo,
    int? posId,
    int? partySize,
    OrderType? orderType,
    int? openTime,
    int? closeTime,
    bool clearCloseTime = false,
    int? waiterId,
    Decimal? tips,
    String? deliveryAddress,
    String? deliveryPhone,
    String? note,
  }) {
    return RestaurantOrderEntity(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      receiptNo: receiptNo ?? this.receiptNo,
      posId: posId ?? this.posId,
      partySize: partySize ?? this.partySize,
      orderType: orderType ?? this.orderType,
      openTime: openTime ?? this.openTime,
      closeTime: clearCloseTime ? null : (closeTime ?? this.closeTime),
      waiterId: waiterId ?? this.waiterId,
      tips: tips ?? this.tips,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryPhone: deliveryPhone ?? this.deliveryPhone,
      note: note ?? this.note,
    );
  }
}
