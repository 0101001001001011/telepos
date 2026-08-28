class ClaimHistoryEntity {
  const ClaimHistoryEntity({
    this.id,
    this.claimId,
    this.action,
    this.oldValue,
    this.newValue,
    this.userId,
    this.deviceId,
    this.timestamp,
    this.notes,
  });

  final int? id;

  final int? claimId;

  final String? action;

  final String? oldValue;

  final String? newValue;

  final int? userId;

  final String? deviceId;

  final int? timestamp;

  final String? notes;

  ClaimHistoryEntity copyWith({
    int? id,
    int? claimId,
    String? action,
    String? oldValue,
    String? newValue,
    int? userId,
    String? deviceId,
    int? timestamp,
    String? notes,
  }) {
    return ClaimHistoryEntity(
      id: id ?? this.id,
      claimId: claimId ?? this.claimId,
      action: action ?? this.action,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
    );
  }
}
