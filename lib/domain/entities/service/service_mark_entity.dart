import 'package:decimal/decimal.dart';

class ServiceMarkEntity {
  const ServiceMarkEntity({
    this.id,
    required this.serviceOrderId,
    required this.description,
    this.markType = 4,
    required this.userId,
    this.cost,
    required this.createdAt,
    this.note,
    this.productUcode,
    this.approvalStatus,
    this.quantity,
  });

  final int? id;
  final int serviceOrderId;
  final String description;

  final int markType;
  final int userId;
  final Decimal? cost;
  final int createdAt;
  final String? note;

  final int? productUcode;

  final int? approvalStatus;

  final Decimal? quantity;

  bool get isConsumable =>
      markType == 5 || (markType == 1 && productUcode != null);

  bool get isPendingApproval => approvalStatus == 0;

  bool get isApproved => approvalStatus == null || approvalStatus == 1;

  bool get isRejected => approvalStatus == 2;

  String get markTypeLabel {
    return switch (markType) {
      0 => 'Диагностика',
      1 => 'Замена детали',
      2 => 'Ремонт',
      3 => 'Тестирование',
      5 => 'Расходный материал',
      _ => 'Прочее',
    };
  }

  ServiceMarkEntity copyWith({
    int? id,
    int? serviceOrderId,
    String? description,
    int? markType,
    int? userId,
    Decimal? cost,
    int? createdAt,
    String? note,
    int? productUcode,
    int? approvalStatus,
    Decimal? quantity,
    bool clearApprovalStatus = false,
  }) {
    return ServiceMarkEntity(
      id: id ?? this.id,
      serviceOrderId: serviceOrderId ?? this.serviceOrderId,
      description: description ?? this.description,
      markType: markType ?? this.markType,
      userId: userId ?? this.userId,
      cost: cost ?? this.cost,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      productUcode: productUcode ?? this.productUcode,
      approvalStatus: clearApprovalStatus
          ? null
          : (approvalStatus ?? this.approvalStatus),
      quantity: quantity ?? this.quantity,
    );
  }
}
