class SerialMovementEntity {
  const SerialMovementEntity({
    this.id,
    this.serialId,
    this.movementType,
    this.fromCellId,
    this.toCellId,
    this.documentType,
    this.documentId,
    this.userId,
    this.deviceId,
    this.timestamp,
    this.notes,
  });

  final int? id;

  final int? serialId;

  final String? movementType;

  final int? fromCellId;

  final int? toCellId;

  final String? documentType;

  final int? documentId;

  final int? userId;

  final String? deviceId;

  final int? timestamp;

  final String? notes;

  SerialMovementEntity copyWith({
    int? id,
    int? serialId,
    String? movementType,
    int? fromCellId,
    int? toCellId,
    String? documentType,
    int? documentId,
    int? userId,
    String? deviceId,
    int? timestamp,
    String? notes,
  }) {
    return SerialMovementEntity(
      id: id ?? this.id,
      serialId: serialId ?? this.serialId,
      movementType: movementType ?? this.movementType,
      fromCellId: fromCellId ?? this.fromCellId,
      toCellId: toCellId ?? this.toCellId,
      documentType: documentType ?? this.documentType,
      documentId: documentId ?? this.documentId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
    );
  }
}
