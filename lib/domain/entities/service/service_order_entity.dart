import 'package:decimal/decimal.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';

class ServiceOrderEntity {
  const ServiceOrderEntity({
    required this.id,
    required this.orderNumber,
    this.receiptNo,
    this.posId,
    this.status = ServiceOrderStatus.intake,
    required this.userId,
    this.assigneeId,
    this.clientAgentId,
    this.clientName,
    this.clientPhone,
    this.clientNote,
    this.deviceDescription,
    this.serialNumber,
    this.complaint,
    required this.intakeTime,
    this.estimatedCompletionTime,
    this.estimatedAmount,
    this.prepaymentAmount,
    this.finalAmount,
    this.warrantyDays,
    this.qualityRating,
    this.qualityNote,
    this.intakeInventory,
  });

  final int id;
  final String orderNumber;
  final int? receiptNo;
  final int? posId;
  final ServiceOrderStatus status;
  final int userId;
  final int? assigneeId;
  final int? clientAgentId;
  final String? clientName;
  final String? clientPhone;
  final String? clientNote;
  final String? deviceDescription;
  final String? serialNumber;
  final String? complaint;
  final int intakeTime;
  final int? estimatedCompletionTime;
  final Decimal? estimatedAmount;
  final Decimal? prepaymentAmount;
  final Decimal? finalAmount;

  final int? warrantyDays;

  final int? qualityRating;

  final String? qualityNote;

  final String? intakeInventory;

  bool get isLinkedToSale => receiptNo != null && posId != null;
  bool get isIntake => status == ServiceOrderStatus.intake;
  bool get isInProgress => status == ServiceOrderStatus.inProgress;
  bool get isCompleted => status == ServiceOrderStatus.completed;
  bool get isClosed => status == ServiceOrderStatus.closed;
  bool get isCancelled => status == ServiceOrderStatus.cancelled;
  bool get isActive => !isClosed && !isCancelled;

  bool get canProgress =>
      status != ServiceOrderStatus.closed &&
      status != ServiceOrderStatus.cancelled;

  ServiceOrderStatus? get nextStatus {
    return switch (status) {
      ServiceOrderStatus.intake => ServiceOrderStatus.inProgress,
      ServiceOrderStatus.inProgress => ServiceOrderStatus.completed,
      ServiceOrderStatus.completed => ServiceOrderStatus.closed,
      _ => null,
    };
  }

  String get clientDisplayName {
    if (clientName != null && clientName!.isNotEmpty) return clientName!;
    if (clientPhone != null && clientPhone!.isNotEmpty) return clientPhone!;
    return 'Клиент #${clientAgentId ?? id}';
  }

  ServiceOrderEntity copyWith({
    int? id,
    String? orderNumber,
    int? receiptNo,
    int? posId,
    ServiceOrderStatus? status,
    int? userId,
    int? assigneeId,
    int? clientAgentId,
    String? clientName,
    String? clientPhone,
    String? clientNote,
    String? deviceDescription,
    String? serialNumber,
    String? complaint,
    int? intakeTime,
    int? estimatedCompletionTime,
    Decimal? estimatedAmount,
    Decimal? prepaymentAmount,
    Decimal? finalAmount,
    int? warrantyDays,
    int? qualityRating,
    String? qualityNote,
    String? intakeInventory,
  }) {
    return ServiceOrderEntity(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      receiptNo: receiptNo ?? this.receiptNo,
      posId: posId ?? this.posId,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      assigneeId: assigneeId ?? this.assigneeId,
      clientAgentId: clientAgentId ?? this.clientAgentId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientNote: clientNote ?? this.clientNote,
      deviceDescription: deviceDescription ?? this.deviceDescription,
      serialNumber: serialNumber ?? this.serialNumber,
      complaint: complaint ?? this.complaint,
      intakeTime: intakeTime ?? this.intakeTime,
      estimatedCompletionTime:
          estimatedCompletionTime ?? this.estimatedCompletionTime,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      prepaymentAmount: prepaymentAmount ?? this.prepaymentAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      qualityRating: qualityRating ?? this.qualityRating,
      qualityNote: qualityNote ?? this.qualityNote,
      intakeInventory: intakeInventory ?? this.intakeInventory,
    );
  }
}
